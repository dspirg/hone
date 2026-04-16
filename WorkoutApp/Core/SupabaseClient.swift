import Supabase

// MARK: - Supabase Singleton
// Single shared instance — multiple instances cause session desynchronization (Anti-Pattern)
// Session stored in Keychain via KeychainLocalStorage — never UserDefaults (T-01-02)
// PKCE flow enforced — never override to .implicit (T-01-03)
// SUPABASE_URL and SUPABASE_ANON_KEY read from Info.plist via xcconfig — never hard-coded (T-01-01)
let supabase = SupabaseClient(
    supabaseURL: URL(string: Bundle.main.infoDictionary?["SUPABASE_URL"] as! String)!,
    supabaseKey: Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as! String,
    options: SupabaseClientOptions(
        auth: .init(
            storage: KeychainLocalStorage(service: Bundle.main.bundleIdentifier!),
            flowType: .pkce,
            redirectToURL: URL(string: "workout://auth-callback")
        )
    )
)
