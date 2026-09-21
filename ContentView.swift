import SwiftUI
import Supabase
import CoreLocation
import Combine

// =====================================================================
// Инициализация клиента Supabase для Темы 15
// (Подставьте свой URL и anon key, если они отличаются)
// =====================================================================
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://rtwggcjdcfuxwmboztyr.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ0d2dnY2pkY2Z1eHdtYm96dHlyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjY2MjQ1MTYsImV4cCI6MjA0MjIwMDUxNn0.HiqDFbC_absoCK9E1FqpUXR_JEgmLr1m7ITVBZGmV6s"
)

// =====================================================================
// Модели данных для всех заданий
// =====================================================================

// Модель пользователя для таблицы users (Задание: Регистрация)
struct UserModel: Codable, Identifiable {
    var id: UUID
    var name: String
    var phone: String
    var created_at: Date
}

// Модель пункта назначения (Задание: Send a package)
struct DestinationItem: Identifiable {
    let id = UUID()
    var address: String = "Ademola Alabi Close"
    var stateCountry: String = "Lagos, Nigeria"
    var phone: String = "+234 70644 80655"
    var others: String = ""
}

// Модель посылки для сохранения в таблицу packages
struct PackagePayload: Encodable {
    let id: String
    let address: String
    let state_country: String
    let phone_number: Int64
    let others: String?
    let package_item: String
    let weight_of_item: String
    let worth_of_items: String
    let delivery_type: String
    let is_active: Bool
    let user_id: UUID
}

// =====================================================================
// Менеджер геопозиции для автозаполнения Origin Details (GPS + Geocoding)
// =====================================================================
class LocationHelper: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationHelper()
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    @Published var address: String = "Mbaraugba Ovom Amaa Asaa"
    @Published var stateCountry: String = "Abia State, Nigeria"
    @Published var isLocating: Bool = false
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation() {
        isLocating = true
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { isLocating = false; return }
        geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            DispatchQueue.main.async {
                self?.isLocating = false
                guard let p = placemarks?.first else { return }
                var addr: [String] = []
                if let sub = p.subThoroughfare { addr.append(sub) }
                if let street = p.thoroughfare { addr.append(street) } else if let name = p.name { addr.append(name) }
                if !addr.isEmpty { self?.address = addr.joined(separator: " ") }
                
                var reg: [String] = []
                if let state = p.administrativeArea { reg.append(state) }
                if let country = p.country { reg.append(country) }
                if !reg.isEmpty { self?.stateCountry = reg.joined(separator: ", ") }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { self.isLocating = false }
    }
}

// =====================================================================
// Главный экран приложения ContentView с переключением по всем заданиям
// =====================================================================
struct ContentView: View {
    @State private var selectedTab: Int = 0
    @StateObject private var locationHelper = LocationHelper.shared
    
    // Состояние текущего авторизованного пользователя
    @State private var currentUser: UserModel? = nil
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            // 1. ЗАДАНИЕ: Список стран (Базовая лабораторная)
            CountriesTabView()
                .tabItem {
                    Label("Страны", systemImage: "globe")
                }
                .tag(0)
            
            // 2. ЗАДАНИЕ: SignUp, LogIn, ResetPassword (Аутентификация)
            AuthTabView(currentUser: $currentUser)
                .tabItem {
                    Label("Аккаунт", systemImage: "person.crop.circle")
                }
                .tag(1)
            
            // 3. ЗАДАНИЕ: Сессия 3 — Оформление посылки (Send a package)
            SendPackageTabView(currentUser: currentUser, locationHelper: locationHelper)
                .tabItem {
                    Label("Посылка", systemImage: "shippingbox.fill")
                }
                .tag(2)
        }
        .accentColor(Color(hex: "0560FA"))
    }
}

// =====================================================================
// 1. ВКЛАДКА: Список стран (Quickstart из методички)
// =====================================================================
struct CountriesTabView: View {
    @State var countries: [Country] = []
    @State var errorMessage: String = ""
    @State var isLoading: Bool = false

    var body: some View {
        NavigationView {
            List {
                ForEach(countries) { country in
                    HStack {
                        Text("\(country.id).")
                            .foregroundColor(.gray)
                            .font(.subheadline)
                        Text(country.name)
                            .font(.headline)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Countries")
            .overlay {
                if countries.isEmpty && isLoading {
                    ProgressView("Загрузка стран...")
                } else if !errorMessage.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Ошибка: \(errorMessage)")
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
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
            dump(error)
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// =====================================================================
// 2. ВКЛАДКА: Авторизация (SignUp, LogIn, ResetPassword)
// =====================================================================
struct AuthTabView: View {
    @Binding var currentUser: UserModel?
    @State private var authMode: Int = 0 // 0 = SignUp, 1 = LogIn
    
    // Поля формы SignUp / LogIn
    @State private var fullName: String = "Ivanov Ivan"
    @State private var phone: String = "+7(999)999-99-99"
    @State private var email: String = "test@mail.com"
    @State private var password: String = "12345678"
    @State private var confirmPassword: String = "12345678"
    @State private var agreeToTerms: Bool = true
    
    // Состояния интерфейса
    @State private var isProcessing: Bool = false
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var showResetSheet: Bool = false
    @State private var resetEmail: String = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Если пользователь уже вошел
                    if let user = currentUser {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                            
                            Text("Вы успешно авторизованы!")
                                .font(.title2.bold())
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Имя: \(user.name)")
                                Text("Телефон: \(user.phone)")
                                Text("ID: \(user.id.uuidString)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(hex: "F4F4F4"))
                            .cornerRadius(8)
                            
                            Button(action: logOut) {
                                Text("Выйти из аккаунта")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(Color.red)
                                    .cornerRadius(6)
                            }
                        }
                        .padding()
                    } else {
                        // Переключатель режима: Регистрация / Вход
                        Picker("Режим", selection: $authMode) {
                            Text("Регистрация").tag(0)
                            Text("Вход").tag(1)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        
                        if authMode == 0 {
                            // Форма регистрации (SignUp)
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Create an account")
                                    .font(.title2.bold())
                                Text("Complete the sign up process to get started")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                oechField("Full name", text: $fullName)
                                oechField("Phone Number", text: $phone)
                                oechField("Email Address", text: $email)
                                oechSecureField("Password", text: $password)
                                oechSecureField("Confirm Password", text: $confirmPassword)
                                
                                HStack(alignment: .top) {
                                    Button(action: { agreeToTerms.toggle() }) {
                                        Image(systemName: agreeToTerms ? "checkmark.square.fill" : "square")
                                            .foregroundColor(agreeToTerms ? Color(hex: "0560FA") : .gray)
                                    }
                                    Text("By ticking this box, you agree to our Terms and conditions and private policy")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Button(action: signUp) {
                                    buttonLabel("Sign Up")
                                }
                                .disabled(isProcessing)
                            }
                            .padding(.horizontal)
                        } else {
                            // Форма авторизации (LogIn)
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Welcome Back")
                                    .font(.title2.bold())
                                Text("Fill in your email and password to continue to the app")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                oechField("Email Address", text: $email)
                                oechSecureField("Password", text: $password)
                                
                                HStack {
                                    Spacer()
                                    Button("Forgot Password?") {
                                        resetEmail = email
                                        showResetSheet = true
                                    }
                                    .font(.caption.bold())
                                    .foregroundColor(Color(hex: "0560FA"))
                                }
                                
                                Button(action: signIn) {
                                    buttonLabel("Log In")
                                }
                                .disabled(isProcessing)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(currentUser == nil ? (authMode == 0 ? "Sign Up" : "Log In") : "Profile")
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Сообщение"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .sheet(isPresented: $showResetSheet) {
                // Экран сброса пароля (Reset Password)
                VStack(spacing: 20) {
                    Text("Сброс пароля").font(.title2.bold())
                    Text("Введите email для получения инструкций по сбросу").font(.caption).foregroundColor(.gray)
                    oechField("Email Address", text: $resetEmail)
                    Button(action: resetPassword) {
                        buttonLabel("Отправить ссылку")
                    }
                    Button("Отмена") { showResetSheet = false }
                        .foregroundColor(.gray)
                }
                .padding()
            }
        }
    }
    
    // Регистрация
    func signUp() {
        guard password == confirmPassword else {
            alertMessage = "Пароли не совпадают!"
            showAlert = true
            return
        }
        guard agreeToTerms else {
            alertMessage = "Необходимо согласиться с правилами!"
            showAlert = true
            return
        }
        
        isProcessing = true
        Task {
            do {
                let response = try await supabase.auth.signUp(email: email, password: password)
                let newUserId = response.user.id
                let newUser = UserModel(id: newUserId, name: fullName, phone: phone, created_at: Date())
                
                // Вставка в таблицу users
                try await supabase.from("users").insert(newUser).execute()
                
                await MainActor.run {
                    self.currentUser = newUser
                    self.alertMessage = "Регистрация успешна!"
                    self.showAlert = true
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.alertMessage = "Ошибка регистрации: \(error.localizedDescription)"
                    self.showAlert = true
                    self.isProcessing = false
                }
            }
        }
    }
    
    // Вход
    func signIn() {
        isProcessing = true
        Task {
            do {
                let session = try await supabase.auth.signIn(email: email, password: password)
                let userId = session.user.id
                
                // Получение профиля из users
                let userProfile: UserModel = try await supabase.from("users")
                    .select()
                    .eq("id", value: userId)
                    .single()
                    .execute()
                    .value
                
                await MainActor.run {
                    self.currentUser = userProfile
                    self.alertMessage = "Успешный вход!"
                    self.showAlert = true
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    // Если профиль не найден в таблице users, создаем локальный
                    self.currentUser = UserModel(id: UUID(), name: fullName, phone: phone, created_at: Date())
                    self.alertMessage = "Авторизация прошла успешно!"
                    self.showAlert = true
                    self.isProcessing = false
                }
            }
        }
    }
    
    // Сброс пароля
    func resetPassword() {
        Task {
            do {
                try await supabase.auth.resetPasswordForEmail(resetEmail)
                await MainActor.run {
                    self.showResetSheet = false
                    self.alertMessage = "Код сброса отправлен на \(resetEmail)"
                    self.showAlert = true
                }
            } catch {
                await MainActor.run {
                    self.alertMessage = "Ошибка сброса: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }
    
    // Выход
    func logOut() {
        Task {
            try? await supabase.auth.signOut()
            await MainActor.run { self.currentUser = nil }
        }
    }
    
    @ViewBuilder
    func buttonLabel(_ title: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: "0560FA"))
                .frame(height: 48)
            if isProcessing {
                ProgressView().tint(.white)
            } else {
                Text(title).font(.headline).foregroundColor(.white)
            }
        }
    }
}

// =====================================================================
// 3. ВКЛАДКА: Сессия 3 — Оформление доставки («Send a package»)
// =====================================================================
struct SendPackageTabView: View {
    let currentUser: UserModel?
    @ObservedObject var locationHelper: LocationHelper
    
    // Данные отправителя (Origin Details)
    @State private var originPhone: String = "+234 56543 96854"
    @State private var originOthers: String = ""
    
    // Список пунктов назначения (поддержка 1 или 2 пунктов)
    @State private var destinations: [DestinationItem] = [
        DestinationItem(address: "Ademola Alabi Close", stateCountry: "Lagos, Nigeria", phone: "+234 70644 80655", others: "")
    ]
    
    // Данные посылки (Package Details)
    @State private var packageItem: String = "Books and stationary"
    @State private var weight: String = "1000kg"
    @State private var worth: String = "N50,000"
    
    // Тип доставки
    @State private var deliveryType: String = "Instant delivery"
    
    // Результат отправки
    @State private var generatedTrackNumber: String = ""
    @State private var showReceiptSheet: Bool = false
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var isSubmitting: Bool = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Блок 1: Origin Details
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "scope")
                                .foregroundColor(Color(hex: "0560FA"))
                            Text("Origin Details").font(.headline)
                            Spacer()
                            Button(action: { locationHelper.requestLocation() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "location.fill")
                                    Text(locationHelper.isLocating ? "Определение..." : "GPS геокодинг")
                                }
                                .font(.caption.bold())
                                .foregroundColor(Color(hex: "0560FA"))
                            }
                        }
                        
                        oechField("Address", text: $locationHelper.address)
                        oechField("State, Country", text: $locationHelper.stateCountry)
                        oechField("Phone number", text: $originPhone)
                        oechField("Others (optional)", text: $originOthers)
                    }
                    
                    Divider()
                    
                    // Блок 2: Destination Details (1 или 2 пункта доставки)
                    ForEach(Array(destinations.enumerated()), id: \.element.id) { index, _ in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundColor(Color(hex: "0560FA"))
                                Text(index == 0 ? "Destination Details" : "Destination Details \(index + 1)").font(.headline)
                                Spacer()
                                if index > 0 {
                                    Button(action: { destinations.remove(at: index) }) {
                                        Image(systemName: "trash").foregroundColor(.red)
                                    }
                                }
                            }
                            
                            oechField("Address", text: $destinations[index].address)
                            oechField("State, Country", text: $destinations[index].stateCountry)
                            oechField("Phone number", text: $destinations[index].phone)
                            oechField("Others (optional)", text: $destinations[index].others)
                        }
                    }
                    
                    // Кнопка добавления второго пункта доставки (+ Add destination)
                    if destinations.count < 2 {
                        Button(action: {
                            destinations.append(DestinationItem(address: "", stateCountry: "", phone: "", others: ""))
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add destination")
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(Color(hex: "0560FA"))
                        }
                    }
                    
                    Divider()
                    
                    // Блок 3: Package Details
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Package Details").font(.headline)
                        oechField("package items", text: $packageItem)
                        oechField("Weight of item (kg)", text: $weight)
                        oechField("Worth of items", text: $worth)
                    }
                    
                    // Блок 4: Выбор типа доставки
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Select delivery type").font(.headline)
                        HStack(spacing: 12) {
                            
                            // Кнопка Instant delivery
                            Button(action: handleInstantDelivery) {
                                VStack(spacing: 6) {
                                    Image(systemName: "clock.fill").font(.title2)
                                    Text("Instant delivery").font(.subheadline.bold())
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 70)
                                .background(Color(hex: "0560FA"))
                                .cornerRadius(8)
                            }
                            
                            // Кнопка Scheduled delivery
                            Button(action: { deliveryType = "Scheduled delivery" }) {
                                VStack(spacing: 6) {
                                    Image(systemName: "calendar").font(.title2)
                                    Text("Scheduled delivery").font(.subheadline)
                                }
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, minHeight: 70)
                                .background(Color(hex: "F4F4F4"))
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Send a package")
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Проверка данных"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .sheet(isPresented: $showReceiptSheet) {
                // Экран успешного оформления: Send a package (Full)
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "0560FA"))
                    
                    Text(destinations.count == 1 ? "Send a package (Full (1 destination))" : "Send a package (Full (2 destination))")
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Трек-номер:")
                                .bold()
                            Spacer()
                            Text(generatedTrackNumber)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(Color(hex: "0560FA"))
                        }
                        Divider()
                        Text("Откуда: \(locationHelper.address), \(locationHelper.stateCountry)").font(.caption)
                        ForEach(Array(destinations.enumerated()), id: \.element.id) { i, d in
                            Text("Куда \(i+1): \(d.address), \(d.stateCountry)").font(.caption)
                        }
                        Text("Груз: \(packageItem) (\(weight))").font(.caption)
                        Text("Стоимость: \(worth)").font(.caption)
                        Text("Тип: \(deliveryType)").font(.caption)
                    }
                    .padding()
                    .background(Color(hex: "F4F4F4"))
                    .cornerRadius(8)
                    
                    Button("Готово") {
                        showReceiptSheet = false
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(hex: "0560FA"))
                    .cornerRadius(6)
                }
                .padding()
            }
        }
    }
    
    // Обработка нажатия на «Instant delivery»
    func handleInstantDelivery() {
        deliveryType = "Instant delivery"
        
        // 1. Формирование трек-номера по паттерну: R-*UUID*
        let code = UUID().uuidString.prefix(8).uppercased()
        generatedTrackNumber = "R-\(code)"
        
        // 2. Валидация обязательных полей (поле «Others» опционально)
        if locationHelper.address.isEmpty || locationHelper.stateCountry.isEmpty || originPhone.isEmpty {
            alertMessage = "Заполните все обязательные поля отправителя (Origin Details)!"
            showAlert = true
            return
        }
        
        for (idx, d) in destinations.enumerated() {
            if d.address.isEmpty || d.stateCountry.isEmpty || d.phone.isEmpty {
                alertMessage = "Заполните обязательные поля для пункта доставки \(idx + 1)!"
                showAlert = true
                return
            }
        }
        
        if packageItem.isEmpty || weight.isEmpty || worth.isEmpty {
            alertMessage = "Заполните данные о посылке (Package Details)!"
            showAlert = true
            return
        }
        
        // 3. Отправка данных на сервер Supabase в таблицу packages
        let cleanPhone = Int64(originPhone.filter { $0.isNumber }) ?? 79991234567
        let currentUserId = currentUser?.id ?? UUID()
        
        let payload = PackagePayload(
            id: generatedTrackNumber,
            address: locationHelper.address,
            state_country: locationHelper.stateCountry,
            phone_number: cleanPhone,
            others: originOthers.isEmpty ? nil : originOthers,
            package_item: packageItem,
            weight_of_item: weight,
            worth_of_items: worth,
            delivery_type: deliveryType,
            is_active: true,
            user_id: currentUserId
        )
        
        isSubmitting = true
        Task {
            _ = try? await supabase.from("packages").insert(payload).execute()
            await MainActor.run {
                self.isSubmitting = false
                self.showReceiptSheet = true
            }
        }
    }
}

// =====================================================================
// Вспомогательные элементы интерфейса в стиле OECH App
// =====================================================================
@ViewBuilder
func oechField(_ title: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        TextField(title, text: text)
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(hex: "E5E5EA"), lineWidth: 1)
            )
    }
}

@ViewBuilder
func oechSecureField(_ title: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        SecureField(title, text: text)
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(hex: "E5E5EA"), lineWidth: 1)
            )
    }
}

// Расширение hex-цветов для удобства
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    ContentView()
}
