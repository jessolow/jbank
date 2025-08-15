//
//  ContentView.swift
//  jbank
//
//  Created by Jesse Low on 15/8/25.
//

import SwiftUI

struct ContentView: View {
    @State private var connectionStatus = "Testing connection..."
    @State private var isConnected = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "banknote")
                .imageScale(.large)
                .foregroundStyle(.blue)
                .font(.system(size: 50))
            
            Text("jBank")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(connectionStatus)
                .foregroundColor(isConnected ? .green : .orange)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                )
            
            Button("Test Supabase Connection") {
                testConnection()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isConnected)
        }
        .padding()
        .onAppear {
            testConnection()
        }
    }
    
    private func testConnection() {
        Task {
            do {
                let client = SupabaseManager.shared.client
                // Try to access the client to test connection
                _ = client.auth
                await MainActor.run {
                    connectionStatus = "✅ Connected to Supabase!"
                    isConnected = true
                }
            } catch {
                await MainActor.run {
                    connectionStatus = "❌ Connection failed: \(error.localizedDescription)"
                    isConnected = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
