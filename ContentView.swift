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
// 2. Модели данных для таблиц 'users' и 'packages'
// (Модель Country находится в файле Country.swift)
// =====================================================================
struct UserModel: Codable, Identifiable {
    var id: UUID
    var name: String
    var phone: String
    var created_at: Date
}

struct PackagePayload: Encodable {
    let id: String
    let address: String
    let state_country: String
    let phone_number: Int64
    let package_item: String
    let weight_of_item: String
    let worth_of_items: String
    let delivery_type: String
    let is_active: Bool
    let user_id: UUID
}

// =====================================================================
// 3. Главный экран приложения (TabView по заданиям лабы)
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

            SendPackageView(currentUser: currentUser)
                .tabItem {
                    Label("Посылка", systemImage: "shippingbox")
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
            List(countries) { country in
                HStack {
                    Text("\(country.id).")
                        .foregroundColor(.secondary)
                    Text(country.name)
                        .fontWeight(.medium)
                }
            }
            .navigationTitle("Страны")
            .overlay {
                if isLoading && countries.isEmpty {
                    ProgressView("Загрузка...")
                } else if !errorMessage.isEmpty {
                    VStack(spacing: 8) {
                        Text("Ошибка: \(errorMessage)")
                            .font(.caption)
                            .foregroundColor(.red)
                        Button("Повторить") {
                            Task { await fetchCountries() }
                        }
                    }
                    .padding()
                }
            }
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
        do {
            countries = try await supabase
                .from("countries")
                .select()
                .execute()
                .value
            errorMessage = ""
        } catch {
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

// =====================================================================
// Задание 3: Оформление посылки (Send a package)
// =====================================================================
struct SendPackageView: View {
    let currentUser: UserModel?

    @State private var address = "ул. Ленина, д. 10"
    @State private var stateCountry = "Москва, Россия"
    @State private var phone = "+7 999 123 45 67"

    @State private var packageItem = "Документы и книги"
    @State private var weight = "2.5 кг"
    @State private var worth = "1500 руб"

    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var isSubmitting = false

    var body: some View {
        NavigationView {
            Form {
                Section("Пункт отправления") {
                    TextField("Адрес", text: $address)
                    TextField("Город, страна", text: $stateCountry)
                    TextField("Телефон", text: $phone)
                }

                Section("Данные посылки") {
                    TextField("Содержимое", text: $packageItem)
                    TextField("Вес", text: $weight)
                    TextField("Ценность", text: $worth)
                }

                Section {
                    Button(action: sendPackage) {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Отправить посылку (Instant delivery)")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
            .navigationTitle("Send a package")
            .alert("Отправка посылки", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    func sendPackage() {
        let trackNumber = "R-\(UUID().uuidString.prefix(6).uppercased())"
        let cleanPhone = Int64(phone.filter { $0.isNumber }) ?? 79991234567
        let userId = currentUser?.id ?? UUID()

        let payload = PackagePayload(
            id: trackNumber,
            address: address,
            state_country: stateCountry,
            phone_number: cleanPhone,
            package_item: packageItem,
            weight_of_item: weight,
            worth_of_items: worth,
            delivery_type: "Instant delivery",
            is_active: true,
            user_id: userId
        )

        isSubmitting = true
        Task {
            do {
                try await supabase.from("packages").insert(payload).execute()
                await MainActor.run {
                    self.alertMessage = "Посылка оформлена! Трек-номер: \(trackNumber)"
                    self.showAlert = true
                    self.isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    self.alertMessage = "Ошибка отправки: \(error.localizedDescription)"
                    self.showAlert = true
                    self.isSubmitting = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
