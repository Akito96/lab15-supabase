import SwiftUI
import Supabase

// =====================================================================
// 1. Клиент Supabase
// (При необходимости подставьте URL и anon key своего проекта)
// =====================================================================
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://rtwggcjdcfuxwmboztyr.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ0d2dnY2pkY2Z1eHdtYm96dHlyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjY2MjQ1MTYsImV4cCI6MjA0MjIwMDUxNn0.HiqDFbC_absoCK9E1FqpUXR_JEgmLr1m7ITVBZGmV6s"
)

// =====================================================================
// 2. Модель данных пользователя для таблицы 'users'
// (Модель Country находится в файле Country.swift)
// =====================================================================
struct UserModel: Codable, Identifiable {
    var id: UUID
    var name: String
    var phone: String
    var created_at: Date
}

// =====================================================================
// 3. Главный экран приложения
// =====================================================================
struct ContentView: View {
    @State private var currentUser: UserModel? = nil

    var body: some View {
        TabView {
            CountriesView()
                .tabItem {
                    Label("Страны", systemImage: "globe")
                }

            AuthView(currentUser: $currentUser)
                .tabItem {
                    Label("Аккаунт", systemImage: "person.circle")
                }
        }
    }
}

// =====================================================================
// Задание 1: Список стран (Quickstart)
// =====================================================================
struct CountriesView: View {
    @State private var countries: [Country] = []
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Group {
                if isLoading && countries.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Загрузка стран...")
                            .foregroundColor(.secondary)
                    }
                } else if !errorMessage.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Повторить") {
                            Task { await fetchCountries() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if countries.isEmpty {
                    VStack(spacing: 12) {
                        Text("В таблице countries нет записей")
                            .foregroundColor(.secondary)
                        Button("Обновить") {
                            Task { await fetchCountries() }
                        }
                    }
                } else {
                    List(countries) { country in
                        HStack {
                            Text("\(country.id).")
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .leading)
                            Text(country.name)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .navigationTitle("Страны")
            .refreshable {
                await fetchCountries()
            }
            .task {
                await fetchCountries()
            }
        }
    }

    func fetchCountries() async {
        isLoading = true
        errorMessage = ""
        do {
            print("--> Запрос стран из Supabase...")
            countries = try await supabase
                .from("countries")
                .select()
                .execute()
                .value
            print("--> Загружено стран: \(countries.count)")
        } catch {
            print("--> Ошибка Supabase: \(error)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// =====================================================================
// Задание 2: Авторизация и регистрация пользователей
// =====================================================================
struct AuthView: View {
    @Binding var currentUser: UserModel?
    @State private var isLoginMode = true

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var password = ""

    @State private var statusMessage = ""
    @State private var isProcessing = false

    var body: some View {
        NavigationView {
            Form {
                if let user = currentUser {
                    Section("Текущий профиль") {
                        Text("Имя: \(user.name)")
                        Text("Телефон: \(user.phone)")
                        Text("ID: \(user.id.uuidString)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button("Выйти из аккаунта", role: .destructive) {
                            signOut()
                        }
                    }
                } else {
                    Section {
                        Picker("Режим", selection: $isLoginMode) {
                            Text("Вход").tag(true)
                            Text("Регистрация").tag(false)
                        }
                        .pickerStyle(.segmented)
                    }

                    Section(isLoginMode ? "Данные для входа" : "Данные регистрации") {
                        if !isLoginMode {
                            TextField("Имя", text: $name)
                            TextField("Телефон", text: $phone)
                        }
                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)
                        SecureField("Пароль", text: $password)
                    }

                    Section {
                        Button(action: {
                            if isLoginMode { signIn() } else { signUp() }
                        }) {
                            if isProcessing {
                                ProgressView()
                            } else {
                                Text(isLoginMode ? "Войти" : "Зарегистрироваться")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(email.isEmpty || password.isEmpty || isProcessing)
                    }

                    if !statusMessage.isEmpty {
                        Section {
                            Text(statusMessage)
                                .font(.footnote)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle(currentUser != nil ? "Профиль" : (isLoginMode ? "Вход" : "Регистрация"))
        }
    }

    func signUp() {
        isProcessing = true
        statusMessage = ""
        Task {
            do {
                let response = try await supabase.auth.signUp(email: email, password: password)
                let newUser = UserModel(
                    id: response.user.id,
                    name: name.isEmpty ? "Пользователь" : name,
                    phone: phone,
                    created_at: Date()
                )
                // Сохраняем пользователя в таблицу 'users'
                try await supabase.from("users").insert(newUser).execute()

                await MainActor.run {
                    self.currentUser = newUser
                    self.statusMessage = "Успешная регистрация!"
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.statusMessage = "Ошибка: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }

    func signIn() {
        isProcessing = true
        statusMessage = ""
        Task {
            do {
                let session = try await supabase.auth.signIn(email: email, password: password)
                
                // Пробуем получить профиль из таблицы 'users'
                let userProfile: UserModel = try await supabase
                    .from("users")
                    .select()
                    .eq("id", value: session.user.id)
                    .single()
                    .execute()
                    .value

                await MainActor.run {
                    self.currentUser = userProfile
                    self.statusMessage = "Вы успешно вошли!"
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    // Если записи в таблице users ещё нет, создаем объект из сессии
                    self.currentUser = UserModel(id: UUID(), name: email, phone: "", created_at: Date())
                    self.statusMessage = "Вход выполнен!"
                    self.isProcessing = false
                }
            }
        }
    }

    func signOut() {
        Task {
            try? await supabase.auth.signOut()
            await MainActor.run {
                self.currentUser = nil
                self.statusMessage = "Вы вышли из системы"
            }
        }
    }
}

#Preview {
    ContentView()
}

