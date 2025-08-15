import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://navolchoccoxcjkkwkcb.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5hdm9sY2hvY2NveGNqa2t3a2NiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUyNTM3MzgsImV4cCI6MjA3MDgyOTczOH0.Dlq4IqAqnKFhzUazMhVjgMCR5rvomDdrm9H4UtTnrbA"
        )
    }
}
