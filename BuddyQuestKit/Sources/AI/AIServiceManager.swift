import Foundation
import Security

/// Central AI service manager. Handles provider selection, fallback chain,
/// API key storage (Keychain), rate limiting, and usage tracking.
///
/// Fallback chain:
///   Apple Intelligence (free, on-device) → BYOT cloud provider → Offline fallback
public final class AIServiceManager: ObservableObject {
    public static let shared = AIServiceManager()

    // MARK: - Published State

    @Published public private(set) var activeProvider: AIProvider = .offline
    @Published public private(set) var isAIEnabled: Bool = false

    // MARK: - Services

    private let appleService = AppleIntelligenceService()
    private let openAIService = OpenAIService()
    private let anthropicService = AnthropicService()

    /// User's preferred cloud provider (when Apple Intelligence is unavailable)
    @Published public var preferredCloudProvider: AIProvider = .openAI {
        didSet { resolveActiveProvider() }
    }

    /// When true, the user has manually chosen a provider instead of using auto-select.
    @Published public var isManualOverride: Bool = false

    /// The user's manually chosen provider (only used when isManualOverride is true)
    @Published public var manualProvider: AIProvider = .offline

    // MARK: - Rate Limiting

    public var maxCallsPerHour: Int = 30
    private var callTimestamps: [Date] = []

    // MARK: - Usage Tracking

    @Published public private(set) var totalCallsThisSession: Int = 0
    @Published public private(set) var estimatedCostThisSession: Double = 0

    // Rough cost per call estimates (GPT-4o-mini / Claude Haiku are very cheap)
    private let costPerCallOpenAI: Double = 0.0003    // ~$0.15/1M input tokens, ~500 tokens/call
    private let costPerCallAnthropic: Double = 0.0003

    // MARK: - Init

    private init() {
        // Load saved keys from Keychain
        if let openAIKey = loadKeyFromKeychain(service: "BuddyQuest_OpenAI") {
            openAIService.setAPIKey(openAIKey)
        }
        if let anthropicKey = loadKeyFromKeychain(service: "BuddyQuest_Anthropic") {
            anthropicService.setAPIKey(anthropicKey)
        }

        // Load preferred provider
        if let saved = UserDefaults.standard.string(forKey: "buddyquest_preferred_cloud_provider"),
           let provider = AIProvider(rawValue: saved) {
            preferredCloudProvider = provider
        }

        // Load manual override setting
        if UserDefaults.standard.bool(forKey: "buddyquest_manual_override"),
           let savedManual = UserDefaults.standard.string(forKey: "buddyquest_manual_provider"),
           let provider = AIProvider(rawValue: savedManual) {
            isManualOverride = true
            manualProvider = provider
        }

        resolveActiveProvider()
    }

    // MARK: - Provider Resolution

    /// Determine the best available provider based on the fallback chain
    public func resolveActiveProvider() {
        // If user has manually selected a provider, honour it
        if isManualOverride {
            switch manualProvider {
            case .appleIntelligence where appleService.isAvailable:
                activeProvider = .appleIntelligence
                isAIEnabled = true
                return
            case .openAI where openAIService.isAvailable:
                activeProvider = .openAI
                isAIEnabled = true
                return
            case .anthropic where anthropicService.isAvailable:
                activeProvider = .anthropic
                isAIEnabled = true
                return
            case .offline:
                activeProvider = .offline
                isAIEnabled = false
                return
            default:
                // Manual choice not available — fall through to auto
                break
            }
        }

        // Auto-select: Apple Intelligence → Cloud → Offline
        // 1. Try Apple Intelligence (free, on-device)
        if appleService.isAvailable {
            activeProvider = .appleIntelligence
            isAIEnabled = true
            return
        }

        // 2. Try preferred cloud provider
        if preferredCloudProvider == .openAI && openAIService.isAvailable {
            activeProvider = .openAI
            isAIEnabled = true
            return
        }
        if preferredCloudProvider == .anthropic && anthropicService.isAvailable {
            activeProvider = .anthropic
            isAIEnabled = true
            return
        }

        // 3. Try the other cloud provider as fallback
        if openAIService.isAvailable {
            activeProvider = .openAI
            isAIEnabled = true
            return
        }
        if anthropicService.isAvailable {
            activeProvider = .anthropic
            isAIEnabled = true
            return
        }

        // 4. Offline
        activeProvider = .offline
        isAIEnabled = false
    }

    /// Let user manually choose a provider. Pass nil to reset to auto-select.
    public func selectProvider(_ provider: AIProvider?) {
        if let provider = provider {
            isManualOverride = true
            manualProvider = provider
            UserDefaults.standard.set(provider.rawValue, forKey: "buddyquest_manual_provider")
            UserDefaults.standard.set(true, forKey: "buddyquest_manual_override")
        } else {
            isManualOverride = false
            UserDefaults.standard.set(false, forKey: "buddyquest_manual_override")
        }
        resolveActiveProvider()
    }

    /// Info about a selectable provider
    public struct ProviderInfo: Identifiable {
        public var id: AIProvider { provider }
        public let provider: AIProvider
        public let label: String
        public let available: Bool
    }

    /// List of providers for the user to select from
    public var availableProviders: [ProviderInfo] {
        [
            ProviderInfo(provider: .appleIntelligence, label: "Apple Intelligence (On-Device)", available: appleService.isAvailable),
            ProviderInfo(provider: .openAI, label: "OpenAI (Cloud)", available: openAIService.isAvailable),
            ProviderInfo(provider: .anthropic, label: "Anthropic (Cloud)", available: anthropicService.isAvailable),
            ProviderInfo(provider: .offline, label: "Offline Question Bank", available: true),
        ]
    }

    /// Get the currently active AI service (or nil for offline)
    public var activeService: AIServiceProtocol? {
        switch activeProvider {
        case .appleIntelligence: return appleService
        case .openAI: return openAIService
        case .anthropic: return anthropicService
        case .offline: return nil
        }
    }

    // MARK: - API Key Management

    public func setOpenAIKey(_ key: String) {
        openAIService.setAPIKey(key.isEmpty ? nil : key)
        saveKeyToKeychain(key: key, service: "BuddyQuest_OpenAI")
        resolveActiveProvider()
        if !key.isEmpty {
            keySaveStatus = "OpenAI key saved to Keychain ✓"
        }
    }

    public func setAnthropicKey(_ key: String) {
        anthropicService.setAPIKey(key.isEmpty ? nil : key)
        saveKeyToKeychain(key: key, service: "BuddyQuest_Anthropic")
        resolveActiveProvider()
        if !key.isEmpty {
            keySaveStatus = "Anthropic key saved to Keychain ✓"
        }
    }

    public var hasOpenAIKey: Bool { openAIService.isAvailable }
    public var hasAnthropicKey: Bool { anthropicService.isAvailable }

    /// Brief confirmation message after saving a key
    @Published public var keySaveStatus: String?

    public var appleIntelligenceAvailable: Bool { appleService.isAvailable }
    public var appleIntelligenceReason: String? { appleService.unavailableReason }

    /// True when the device supports Apple Intelligence but the model is still downloading.
    /// The OS downloads the model automatically — no user action needed.
    public var isAppleIntelligenceDownloading: Bool {
        guard !appleService.isAvailable else { return false }
        let reason = appleService.unavailableReason ?? ""
        return reason.contains("downloading")
    }

    /// Re-check Apple Intelligence availability and update provider if it became ready.
    /// Call this periodically or from a "Check Again" button.
    public func refreshAppleIntelligenceStatus() {
        let wasAvailable = appleService.isAvailable
        // Re-resolve — if the model just finished downloading, this will pick it up
        resolveActiveProvider()
        // Notify observers by tickling @Published (objectWillChange fires from resolveActiveProvider)
        if !wasAvailable && appleService.isAvailable {
            print("[AIServiceManager] Apple Intelligence became available!")
        }
    }

    public func setPreferredCloudProvider(_ provider: AIProvider) {
        preferredCloudProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: "buddyquest_preferred_cloud_provider")
    }

    // MARK: - Rate Limiting

    /// Check if we're within rate limits. Returns true if allowed.
    public func checkRateLimit() -> Bool {
        guard activeProvider != .appleIntelligence else { return true } // No limit for on-device
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        callTimestamps = callTimestamps.filter { $0 > oneHourAgo }
        return callTimestamps.count < maxCallsPerHour
    }

    /// Record a successful API call for rate limiting and usage tracking
    public func recordCall() {
        callTimestamps.append(Date())
        totalCallsThisSession += 1

        if activeProvider == .openAI {
            estimatedCostThisSession += costPerCallOpenAI
        } else if activeProvider == .anthropic {
            estimatedCostThisSession += costPerCallAnthropic
        }
        // Apple Intelligence = $0
    }

    public var callsRemainingThisHour: Int {
        guard activeProvider != .appleIntelligence else { return 999 }
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let recentCalls = callTimestamps.filter { $0 > oneHourAgo }.count
        return max(0, maxCallsPerHour - recentCalls)
    }

    // MARK: - Test Connection

    /// Quick test to verify the active provider works
    public func testConnection() async -> (success: Bool, message: String) {
        guard let service = activeService else {
            return (false, "No AI provider configured")
        }

        do {
            let _ = try await service.generateBuddyDialogue(
                buddyName: "Nova",
                buddyPersonality: "Curious and friendly",
                context: BuddyDialogueContext(trigger: "test", playerLevel: 1)
            )
            return (true, "\(service.provider.displayName) is working!")
        } catch let error as AIServiceError {
            return (false, error.localizedDescription ?? "Unknown error")
        } catch {
            return (false, error.localizedDescription)
        }
    }

    // MARK: - Keychain Helpers

    private func saveKeyToKeychain(key: String, service: String) {
        let data = key.data(using: .utf8)!

        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "api_key"
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        guard !key.isEmpty else { return }

        // Add new
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "api_key",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func loadKeyFromKeychain(service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "api_key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
