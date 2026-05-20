import Combine
import Foundation
import WatchConnectivity
#if os(watchOS)
import HealthKit
#endif

@MainActor
final class WorkoutManager: NSObject, ObservableObject {
    static let shared = WorkoutManager()

    // MARK: - Published state

    @Published var templates: [WatchTemplate] = []
    @Published var isPhoneReachable = false

    @Published var activeSession: ActiveWatchSession?

    @Published var isResting = false
    @Published var restSecondsRemaining = 0
    @Published var restTotalSeconds = 60

    @Published var heartRate: Double = 0
    @Published var elapsedSeconds = 0

    // Haptic triggers — views observe these with .sensoryFeedback
    @Published var hapticRestStart = false
    @Published var hapticTimerEnd = false

    // MARK: - Private

    private var restTimer: Timer?
    private var elapsedTimer: Timer?
    private var shouldAdvanceOnRestEnd = false

    #if os(watchOS)
    private let healthStore = HKHealthStore()
    private var hkSession: HKWorkoutSession?
    private var hkBuilder: HKLiveWorkoutBuilder?
    #endif

    private static let templatesCacheKey = "cached_templates"

    private override init() {
        super.init()
        templates = Self.loadCachedTemplates()
        setupConnectivity()
        #if os(watchOS)
        requestHealthPermissions()
        #endif
    }

    // MARK: - Workout control

    func startWorkout(template: WatchTemplate) {
        let session = ActiveWatchSession(template: template)
        activeSession = session
        elapsedSeconds = 0
        startElapsedTimer()
        sendToPhone([
            "action": "start_workout",
            "sessionId": session.id,
            "templateId": template.id,
            "startedAt": Date().timeIntervalSince1970 * 1000,
        ] as [String: Any])
        #if os(watchOS)
        startHKWorkout()
        #endif
    }

    func completeSet() {
        guard var session = activeSession, !isResting else { return }
        let exercise = session.currentExercise
        let setNumber = session.setsCompletedForCurrent + 1
        session.setsCompleted[session.currentExerciseIndex] += 1
        activeSession = session

        sendToPhone([
            "action": "complete_set",
            "sessionId": session.id,
            "exerciseIndex": session.currentExerciseIndex,
            "setNumber": setNumber,
            "reps": exercise.targetReps,
            "weight": exercise.targetWeight ?? 0.0,
        ] as [String: Any])

        let advance = session.isCurrentExerciseDone && !session.isLastExercise
        startRestTimer(seconds: exercise.restSeconds, advanceAfter: advance)
    }

    func skipRest() {
        let shouldAdvance = shouldAdvanceOnRestEnd
        stopRestTimer()
        if shouldAdvance { nextExercise() }
    }

    func nextExercise() {
        guard var session = activeSession, !session.isLastExercise else { return }
        session.currentExerciseIndex += 1
        activeSession = session
    }

    func previousExercise() {
        guard var session = activeSession, !session.isFirstExercise else { return }
        session.currentExerciseIndex -= 1
        activeSession = session
        stopRestTimer()
    }

    func finishWorkout() {
        guard let session = activeSession else { return }
        sendToPhone(["action": "finish_workout", "sessionId": session.id, "healthkitSaved": true])
        stopRestTimer()
        stopElapsedTimer()
        #if os(watchOS)
        finishHKWorkout()
        #endif
        activeSession = nil
        heartRate = 0
        elapsedSeconds = 0
    }

    // MARK: - Rest timer

    private func startRestTimer(seconds: Int, advanceAfter: Bool) {
        stopRestTimer()
        restTotalSeconds = max(seconds, 1)
        restSecondsRemaining = restTotalSeconds
        isResting = true
        shouldAdvanceOnRestEnd = advanceAfter
        hapticRestStart.toggle()

        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.restSecondsRemaining > 0 {
                    self.restSecondsRemaining -= 1
                } else {
                    self.timerDidFinish()
                }
            }
        }
    }

    private func timerDidFinish() {
        hapticTimerEnd.toggle()
        let shouldAdvance = shouldAdvanceOnRestEnd
        stopRestTimer()
        if shouldAdvance { nextExercise() }
    }

    private func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        isResting = false
        restSecondsRemaining = 0
        shouldAdvanceOnRestEnd = false
    }

    // MARK: - Elapsed timer

    private func startElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.elapsedSeconds += 1 }
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    // MARK: - WatchConnectivity

    private func setupConnectivity() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendToPhone(_ message: [String: Any]) {
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(message)
        }
    }

    private func handlePhoneMessage(_ message: [String: Any]) {
        guard let action = message["action"] as? String else { return }
        if action == "sync_templates",
           let json = message["data"] as? String,
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([WatchTemplate].self, from: data) {
            templates = decoded
            Self.cacheTemplates(decoded)
        }
    }

    // MARK: - Template caching

    private static func cacheTemplates(_ templates: [WatchTemplate]) {
        if let data = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(data, forKey: templatesCacheKey)
        }
    }

    private static func loadCachedTemplates() -> [WatchTemplate] {
        guard let data = UserDefaults.standard.data(forKey: templatesCacheKey),
              let templates = try? JSONDecoder().decode([WatchTemplate].self, from: data)
        else { return [] }
        return templates
    }

    // MARK: - HealthKit (watchOS only)

    #if os(watchOS)
    private func requestHealthPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let share: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
        ]
        let read: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
        ]
        healthStore.requestAuthorization(toShare: share, read: read) { _, _ in }
    }

    private func startHKWorkout() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore, workoutConfiguration: config)
            session.delegate = self
            builder.delegate = self
            hkSession = session
            hkBuilder = builder
            session.startActivity(with: Date())
            builder.beginCollection(withStart: Date()) { _, _ in }
        } catch {
            print("HKWorkoutSession error: \(error)")
        }
    }

    private func finishHKWorkout() {
        hkSession?.end()
        hkBuilder?.endCollection(withEnd: Date()) { [weak self] _, _ in
            self?.hkBuilder?.finishWorkout { _, _ in }
        }
    }
    #endif
}

// MARK: - WCSessionDelegate

extension WorkoutManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            self?.isPhoneReachable = session.isReachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            self?.isPhoneReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor [weak self] in self?.handlePhoneMessage(message) }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor [weak self] in self?.handlePhoneMessage(applicationContext) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor [weak self] in self?.handlePhoneMessage(userInfo) }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif
}

// MARK: - HealthKit delegates (watchOS only)

#if os(watchOS)
extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {}
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate),
              collectedTypes.contains(hrType)
        else { return }

        let bpm = workoutBuilder
            .statistics(for: hrType)?
            .mostRecentQuantity()?
            .doubleValue(for: HKUnit.count().unitDivided(by: .minute())) ?? 0

        Task { @MainActor [weak self] in self?.heartRate = bpm }
    }
}
#endif
