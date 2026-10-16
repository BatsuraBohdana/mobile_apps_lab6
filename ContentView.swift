import SwiftUI
import Combine

enum UserRole: String, Codable {
    case guest = "Гість"
    case user = "Користувач"
    case admin = "Адміністратор"
}

struct UserAccount: Codable, Identifiable {
    var id = UUID()
    let name: String
    let login: String
    let password: String
    var role: UserRole
}

class CloudMovieDatabase: ObservableObject {
    private let dbKey = "lumiere_cloud_users_db"
    @Published var users: [UserAccount] = []
    
    init() {
        loadDatabase()
        if users.isEmpty {
            users = [
                UserAccount(name: "Богдана", login: "bohdana", password: "123", role: .user),
                UserAccount(name: "Головний Адмін", login: "admin", password: "admin123", role: .admin)
            ]
            saveDatabase()
        }
    }
    
    func register(name: String, login: String, pass: String) -> (success: Bool, message: String) {
        if users.contains(where: { $0.login.lowercased() == login.lowercased() }) {
            return (false, "Користувач із таким логіном вже існує!")
        }
        let newUser = UserAccount(name: name, login: login, password: pass, role: .user)
        users.append(newUser)
        saveDatabase()
        return (true, "Реєстрація успішна!")
    }
    
    func authenticate(login: String, pass: String) -> UserAccount? {
        return users.first(where: { $0.login.lowercased() == login.lowercased() && $0.password == pass })
    }
    
    private func saveDatabase() {
        if let encoded = try? JSONEncoder().encode(users) {
            UserDefaults.standard.set(encoded, forKey: dbKey)
        }
    }
    
    private func loadDatabase() {
        if let data = UserDefaults.standard.data(forKey: dbKey),
           let decoded = try? JSONDecoder().decode([UserAccount].self, from: data) {
            self.users = decoded
        }
    }
}

// Модель фільму каталогу
struct MovieItem: Identifiable, Hashable {
    let id: String
    let key: String
    let category: String
    var watchProgress: Double = 0.0
    var duration: String = "2 год 15 хв"
}

// Плитка жанру для вкладки Пошук
struct SearchGenreTile: Identifiable {
    let id = UUID()
    let key: String
    let nameUA: String
    let nameEN: String
    let icon: String
    let gradient: [Color]
}

// Модель відгуку
struct MovieComment: Identifiable, Equatable {
    let id = UUID()
    let author: String
    let text: String
    let time: String
    var isAdmin: Bool = false
}

// =================================================================
// 2. ГОЛОВНИЙ ЕКРАН ДОДАТКА LUMIÈRE
// =================================================================
struct ContentView: View {
    @StateObject private var database = CloudMovieDatabase()
    
    // ТЕМА ОФОРМЛЕННЯ
    @AppStorage("lumiere_is_dark_mode") private var isDarkMode: Bool = true
    
    // ОБРАНІ ФІЛЬМИ
    @AppStorage("lumiere_favorites_keys") private var favoritesKeysString: String = "movie1,movie2,movie3"
    
    // СТАН АНІМАЦІЇ ЗАСТАВКИ (SPLASH SCREEN)
    @State private var isShowingSplash: Bool = true
    @State private var splashScale: CGFloat = 0.7
    @State private var splashOpacity: Double = 0.0
    
    // НАВІГАЦІЯ ПО ТАБАХ
    @State private var selectedTab: String = "home"
    @State private var currentLanguage: String = "ua"
    @State private var selectedMovie: String = "movie1"
    
    // ПОШУК ТА РУБРИКИ
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "all"
    
    // 3 РОЛІ КОРИСТУВАЧІВ
    @State private var currentUser: UserAccount? = nil
    @State private var showAuthModal: Bool = false
    @State private var showProfileModal: Bool = false
    
    // ТАЙМЕР СЕСІЇ (5 хвилин)
    @State private var sessionRemainingSeconds: Int = 300
    @State private var isSessionActive: Bool = false
    let sessionTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    // МОДАЛЬНІ ВІКНА
    @State private var showDetailScreen: Bool = false
    @State private var showMovieSummarySheet: Bool = false
    @State private var showAdminAddMovieModal: Bool = false
    
    // 11 фільмів із прогресом
    @State private var movieCatalog: [MovieItem] = [
        MovieItem(id: "1", key: "movie1", category: "sci_fi", watchProgress: 0.65, duration: "2 год 45 хв"),
        MovieItem(id: "2", key: "movie2", category: "adventure", watchProgress: 0.40, duration: "2 год 35 хв"),
        MovieItem(id: "3", key: "movie3", category: "sci_fi", watchProgress: 0.85, duration: "2 год 49 хв"),
        MovieItem(id: "4", key: "movie4", category: "comedy", watchProgress: 0.20, duration: "1 год 54 хв"),
        MovieItem(id: "5", key: "movie5", category: "sci_fi", watchProgress: 0.90, duration: "2 год 42 хв"),
        MovieItem(id: "6", key: "movie6", category: "drama", watchProgress: 0.50, duration: "3 год 14 хв"),
        MovieItem(id: "7", key: "movie7", category: "animation", watchProgress: 0.15, duration: "1 год 40 хв"),
        MovieItem(id: "8", key: "movie8", category: "animation", watchProgress: 0.0, duration: "1 год 47 хв"),
        MovieItem(id: "9", key: "movie9", category: "animation", watchProgress: 0.30, duration: "1 год 40 хв"),
        MovieItem(id: "10", key: "movie10", category: "comedy", watchProgress: 0.75, duration: "1 год 26 хв"),
        MovieItem(id: "11", key: "movie11", category: "animation", watchProgress: 0.60, duration: "1 год 51 хв")
    ]
    
    // Плитки жанрів для пошуку
    let genreTiles: [SearchGenreTile] = [
        SearchGenreTile(key: "sci_fi", nameUA: "Фантастика", nameEN: "Sci-Fi", icon: "sparkles.tv", gradient: [Color.blue, Color.purple]),
        SearchGenreTile(key: "adventure", nameUA: "Пригоди", nameEN: "Adventure", icon: "map.fill", gradient: [Color.orange, Color.red]),
        SearchGenreTile(key: "drama", nameUA: "Драма", nameEN: "Drama", icon: "theatermasks.fill", gradient: [Color.purple, Color.indigo]),
        SearchGenreTile(key: "comedy", nameUA: "Комедія", nameEN: "Comedy", icon: "face.smiling.fill", gradient: [Color.yellow, Color.orange]),
        SearchGenreTile(key: "animation", nameUA: "Анімація", nameEN: "Animation", icon: "wand.and.stars", gradient: [Color.pink, Color.purple]),
        SearchGenreTile(key: "family", nameUA: "Сімейні", nameEN: "Kids & Family", icon: "figure.2.and.child.holdinghands", gradient: [Color.teal, Color.blue])
    ]
    
    // Відгуки глядачів
    @State private var commentsByMovie: [String: [MovieComment]] = [
        "movie2": [
            MovieComment(author: "Богдана", text: "Новий епос Нолана 2026 — це просто візуальний розрив!", time: "14:10"),
            MovieComment(author: "Адмін", text: "Головна прем'єра року. Обов'язково дивитися на великому екрані.", time: "14:20", isAdmin: true)
        ],
        "movie1": [MovieComment(author: "Глядач", text: "Перша частина Дюни занурює в атмосферу пустелі на всі 100%!", time: "12:00")],
        "movie3": [MovieComment(author: "Марія", text: "Найкраща наукова фантастика XXI століття.", time: "13:40")],
        "movie4": [MovieComment(author: "Аліна", text: "Візуальний стиль та костюми — це щось нереальне!", time: "15:10")],
        "movie5": [MovieComment(author: "Джейк", text: "Пандора неймовірно красива в 3D!", time: "11:20")],
        "movie6": [MovieComment(author: "Роза", text: "Легендарна історія кохання 😭", time: "16:05")],
        "movie7": [MovieComment(author: "Мауї", text: "Океан знову кличе у подорож! 🌊", time: "17:15")],
        "movie8": [MovieComment(author: "Сісу", text: "Неймовірна східна атмосфера та круті бої 🐉", time: "18:20")],
        "movie9": [MovieComment(author: "Вовк", text: "Дуже смішний і динамічний мульт!", time: "19:00")],
        "movie10": [MovieComment(author: "Джуліан", text: "I like to move it, move it! 🐒", time: "13:10")],
        "movie11": [MovieComment(author: "Еґо", text: "Готувати може кожен! Найдушевніший мультфільм 🧀", time: "20:30")]
    ]

    // База текстів (без дубльованих спецсимволів у назвах кнопок)
    let texts: [String: [String: String]] = [
        "ua": [
            "app_title": "Lumière",
            "login_btn": "Увійти",
            "role_guest": "Гість",
            "category_label": "Рубрика:",
            "cat_all": "Усі фільми",
            "cat_sci_fi": "Фантастика",
            "cat_adventure": "Пригоди",
            "cat_drama": "Драма",
            "cat_animation": "Анімація",
            "cat_comedy": "Комедія",
            "btn_about_movie": "Про фільм",
            "btn_play": "Дивитися",
            "btn_favorite_add": "В обране",
            "btn_favorite_remove": "В обраному",
            "section_continue": "Продовжити перегляд",
            "section_top10": "Топ-10 фільмів у Lumière",
            "section_new": "Новинки та рекомендації",
            "section_favorites": "Моє обране",
            "favorites_empty_title": "Список обраного порожній",
            "favorites_empty_desc": "Натисніть «В обране» на будь-якому фільмі, щоб зберегти його для перегляду.",
            
            "tab_home": "Домівка",
            "tab_search": "Пошук",
            "tab_library": "Обране",
            "tab_store": "Квитки",
            
            "search_placeholder": "Фільми, жанри, режисери...",
            "search_categories": "Жанрові рубрики",
            "search_no_results": "За вашим запитом нічого не знайдено",
            
            // 1. Одіссея (2026, Крістофер Нолан)
            "movie2_title": "Одіссея",
            "movie2_genre": "Фантастика, Епос",
            "movie2_year": "2026",
            "movie2_rating": "9.2",
            "movie2_director": "Крістофер Нолан",
            "movie2_desc": "Новий довгоочікуваний науково-фантастичний епос Крістофера Нолана 2026 року за мотивами поеми Гомера.",
            "movie2_synopsis": "Грандіозна кіноадаптація безсмертної «Одіссеї» від маестро Крістофера Нолана. Після завершення багаторічної міжзоряної війни Одіссей вирушає у небезпечну подорож додому крізь незвідані галактичні сектори, просторово-часові розриви та гравітаційні аномалії, долаючи міфічні сили всесвіту, щоб возз'єднатися з родиною.",
            
            // 2. Дюна: Частина перша (2021, Дені Вільнев)
            "movie1_title": "Дюна: Частина перша",
            "movie1_genre": "Фантастика, Пригоди",
            "movie1_year": "2021",
            "movie1_rating": "8.5",
            "movie1_director": "Дені Вільнев",
            "movie1_desc": "Початок легендарної подорожі Пола Атріда на пустельну планету Арракіс.",
            "movie1_synopsis": "Юний Пол Атрід вирушає разом із шляхетною родиною на найнебезпечнішу та найважливішу планету у всесвіті — Арракіс. Саме тут видобувають безцінну пряність «меланж», яка подовжує життя та відкриває надлюдські здібності. Коли родину зраджують вороги, Пол мусить пройти крізь вогонь пустелі та знайти свою долю серед гігантських хробаків і народу фременів.",
            
            // 3. Інтерстеллар
            "movie3_title": "Інтерстеллар",
            "movie3_genre": "Наукова фантастика",
            "movie3_year": "2014",
            "movie3_rating": "8.7",
            "movie3_director": "Крістофер Нолан",
            "movie3_desc": "Подорож крізь червоточину в пошуках нового дому для виживання людства.",
            "movie3_synopsis": "Земля стоїть на порозі продовольчої кризи та вимирання. Колишній пілот НАСА Купер очолює експедицію крізь відкриту біля Сатурна червоточину в іншу галактику, шукаючи придатну для колонізації планету.",
            
            // 4. Барбі
            "movie4_title": "Барбі",
            "movie4_genre": "Комедія, Фентезі",
            "movie4_year": "2023",
            "movie4_rating": "6.8",
            "movie4_director": "Ґрета Ґервіґ",
            "movie4_desc": "Барбі та Кен вирушають із безтурботного Барбіленду в реальний світ у пошуках себе.",
            "movie4_synopsis": "Жити в ідеальному світі Барбіленд — це щастя, якщо тільки в тебе немає кризи існування. Барбі вирушає у справжній світ людей, де на неї та Кена чекають кумедні та глибокі відкриття про людську природу.",
            
            // 5. Аватар
            "movie5_title": "Аватар",
            "movie5_genre": "Фантастика, Екшн",
            "movie5_year": "2009",
            "movie5_rating": "7.9",
            "movie5_director": "Джеймс Кемерон",
            "movie5_desc": "Джейк Саллі потрапляє на планету Пандора та стає на захист народу На'ві.",
            "movie5_synopsis": "Колишній морпіх Джейк Саллі прибуває на багату ресурсів Пандору. Керуючи штучним тілом аватара, він закохується у войовницю Нейтірі та очолює спротив корінних жителів проти експансії земних корпорацій.",
            
            // 6. Титанік
            "movie6_title": "Титанік",
            "movie6_genre": "Драма, Романтика",
            "movie6_year": "1997",
            "movie6_rating": "7.9",
            "movie6_director": "Джеймс Кемерон",
            "movie6_desc": "Легендарна історія кохання бідного художника Джека та аристократки Рози.",
            "movie6_synopsis": "На борту гігантського лайнера «Титанік» спалахує щире кохання між молодим художником Джеком і багатою нареченою Розою перед лицем фатальної морської катастрофи.",
            
            // 7. Ваяна 2
            "movie7_title": "Ваяна 2",
            "movie7_genre": "Анімація, Пригоди",
            "movie7_year": "2024",
            "movie7_rating": "7.1",
            "movie7_director": "Девід Деррік мол.",
            "movie7_desc": "Ваяна вирушає у нову велику мандрівку океанськими просторами.",
            "movie7_synopsis": "Отримавши несподіваний заклик від предків, відважна Ваяна разом із напівбогом Мауї вирушає у небезпечні далекі води Океанії.",
            
            // 8. Рая та останній дракон
            "movie8_title": "Рая та останній дракон",
            "movie8_genre": "Анімація, Фентезі",
            "movie8_year": "2021",
            "movie8_rating": "7.3",
            "movie8_director": "Дон Голл",
            "movie8_desc": "Відважна воїтелька шукає останнього дракона для порятунку свого королівства.",
            "movie8_synopsis": "У чарівній країні Кумандра воїтелька Рая мусить відшукати легендарну драконицю Сісу, щоб повернути довіру та мир між племенами.",
            
            // 9. Поганці
            "movie9_title": "Поганці",
            "movie9_genre": "Анімація, Комедія",
            "movie9_year": "2022",
            "movie9_rating": "6.8",
            "movie9_director": "П'єр Періфел",
            "movie9_desc": "Банда звірів-шахраїв намагається стати зразковими громадянами.",
            "movie9_synopsis": "Спритна банда звірів-грабіжників на чолі з Містером Вовком після невдалої крадіжки намагається довести суспільству, що вони здатні чинити добро.",
            
            // 10. Мадагаскар
            "movie10_title": "Мадагаскар",
            "movie10_genre": "Комедія, Сімейний",
            "movie10_year": "2005",
            "movie10_rating": "6.9",
            "movie10_director": "Ерік Дарнелл",
            "movie10_desc": "Пригоди розпещених звірів нью-йоркського зоопарку на дикому острові.",
            "movie10_synopsis": "Лев Алекс, зебра Марті, жираф Мелман і бегемотиха Глорія опиняються на острові Мадагаскар під веселе правління короля Джуліана.",
            
            // 11. Рататуй
            "movie11_title": "Рататуй",
            "movie11_genre": "Анімація, Комедія",
            "movie11_year": "2007",
            "movie11_rating": "8.1",
            "movie11_director": "Бред Берд",
            "movie11_desc": "Історія щурика-кулінара Ремі в престижному ресторані Парижа.",
            "movie11_synopsis": "Пацюк Ремі мріє стати шеф-кухарем. Об'єднавшись із прибиральником Лінгвіні, він таємно готує шедеври французької кухні."
        ],
        "en": [
            "app_title": "Lumière",
            "login_btn": "Sign In",
            "role_guest": "Guest",
            "category_label": "Category:",
            "cat_all": "All Movies",
            "cat_sci_fi": "Sci-Fi",
            "cat_adventure": "Adventure",
            "cat_drama": "Drama",
            "cat_animation": "Animation",
            "cat_comedy": "Comedy",
            "btn_about_movie": "Synopsis",
            "btn_play": "Play",
            "btn_favorite_add": "Add to List",
            "btn_favorite_remove": "In Favorites",
            "section_continue": "Continue Watching",
            "section_top10": "Top 10 Movies on Lumière",
            "section_new": "New Releases & Featured",
            "section_favorites": "My Favorites",
            "favorites_empty_title": "Your Favorites is Empty",
            "favorites_empty_desc": "Tap «Add to List» on any movie to save it here for later.",
            
            "tab_home": "Home",
            "tab_search": "Search",
            "tab_library": "Favorites",
            "tab_store": "Tickets",
            
            "search_placeholder": "Shows, Movies and More...",
            "search_categories": "Browse Categories",
            "search_no_results": "No results found for your query",
            
            // 1
            "movie2_title": "The Odyssey",
            "movie2_genre": "Sci-Fi, Epic",
            "movie2_year": "2026",
            "movie2_rating": "9.2",
            "movie2_director": "Christopher Nolan",
            "movie2_desc": "Christopher Nolan's highly anticipated 2026 sci-fi epic inspired by Homer's classic tale.",
            "movie2_synopsis": "Following a decade-long interstellar conflict, Odysseus embarks on an arduous voyage home across uncharted cosmic sectors to reunite with his family.",
            
            // 2
            "movie1_title": "Dune: Part One",
            "movie1_genre": "Sci-Fi, Adventure",
            "movie1_year": "2021",
            "movie1_rating": "8.5",
            "movie1_director": "Denis Villeneuve",
            "movie1_desc": "The beginning of Paul Atreides' mythical journey on the desert planet Arrakis.",
            "movie1_synopsis": "Paul Atreides travels to the most dangerous planet in the universe to secure the future of his people while facing destiny among the Fremen.",
            
            // 3
            "movie3_title": "Interstellar",
            "movie3_genre": "Sci-Fi, Drama",
            "movie3_year": "2014",
            "movie3_rating": "8.7",
            "movie3_director": "Christopher Nolan",
            "movie3_desc": "A team of explorers travels through a wormhole in search of a new home.",
            "movie3_synopsis": "When Earth becomes uninhabitable, a team of astronauts embarks on an interstellar expedition across space and time to save humankind.",
            
            // 4
            "movie4_title": "Barbie",
            "movie4_genre": "Comedy, Fantasy",
            "movie4_year": "2023",
            "movie4_rating": "6.8",
            "movie4_director": "Greta Gerwig",
            "movie4_desc": "Barbie and Ken venture into the real world on a journey of self-discovery.",
            "movie4_synopsis": "To live in Barbie Land is to be a perfect being in a perfect place. Unless you have a full-on existential crisis.",
            
            // 5
            "movie5_title": "Avatar",
            "movie5_genre": "Sci-Fi, Action",
            "movie5_year": "2009",
            "movie5_rating": "7.9",
            "movie5_director": "James Cameron",
            "movie5_desc": "A paralyzed marine dispatched to Pandora becomes torn between duty and love.",
            "movie5_synopsis": "Jake Sully infiltrates the native Na'vi using an avatar body, but soon chooses to fight alongside them to protect Pandora.",
            
            // 6
            "movie6_title": "Titanic",
            "movie6_genre": "Drama, Romance",
            "movie6_year": "1997",
            "movie6_rating": "7.9",
            "movie6_director": "James Cameron",
            "movie6_desc": "A seventeen-year-old aristocrat falls in love with a kind but poor artist aboard Titanic.",
            "movie6_synopsis": "Jack and Rose find forbidden love aboard the luxury ship Titanic, facing tragic peril when it strikes an iceberg.",
            
            // 7
            "movie7_title": "Moana 2",
            "movie7_genre": "Animation, Adventure",
            "movie7_year": "2024",
            "movie7_rating": "7.1",
            "movie7_director": "David Derrick Jr.",
            "movie7_desc": "Moana journeys to the far seas of Oceania on a dangerous voyage.",
            "movie7_synopsis": "After receiving an unexpected call from her ancestors, Moana journeys to the far seas of Oceania with Maui.",
            
            // 8
            "movie8_title": "Raya and the Last Dragon",
            "movie8_genre": "Fantasy, Animation",
            "movie8_year": "2021",
            "movie8_rating": "7.3",
            "movie8_director": "Don Hall",
            "movie8_desc": "A lone warrior tracks down the legendary last dragon to save Kumandra.",
            "movie8_synopsis": "Warrior Raya must track down the legendary last dragon Sisu to restore peace to Kumandra.",
            
            // 9
            "movie9_title": "The Bad Guys",
            "movie9_genre": "Comedy, Animation",
            "movie9_year": "2022",
            "movie9_rating": "6.8",
            "movie9_director": "Pierre Perifel",
            "movie9_desc": "A crackerjack crew of animal outlaws attempts to become good.",
            "movie9_synopsis": "Several reformed criminal animals attempt to become good, with hilarious results along the way.",
            
            // 10
            "movie10_title": "Madagascar",
            "movie10_genre": "Comedy, Family",
            "movie10_year": "2005",
            "movie10_rating": "6.9",
            "movie10_director": "Eric Darnell",
            "movie10_desc": "Four zoo animals find themselves unexpectedly stranded in Madagascar.",
            "movie10_synopsis": "Animals from Central Park Zoo accidentally find themselves shipwrecked on the wild island of Madagascar.",
            
            // 11
            "movie11_title": "Ratatouille",
            "movie11_genre": "Animation, Comedy",
            "movie11_year": "2007",
            "movie11_rating": "8.1",
            "movie11_director": "Brad Bird",
            "movie11_desc": "A rat who can cook makes an unusual alliance with a young kitchen worker.",
            "movie11_synopsis": "Remy, an ambitious young rat endowed with sophisticated taste, teams up with a clumsy kitchen worker in Paris."
        ]
    ]

    // ДИНАМІЧНА ПАЛІТРА ДЛЯ СВІТЛОЇ ТА ТЕМНОЇ ТЕМИ
    var themeBackground: Color {
        isDarkMode ? Color.black : Color(red: 0.95, green: 0.95, blue: 0.97)
    }
    
    var themeCardBackground: Color {
        isDarkMode ? Color(white: 0.14) : Color.white
    }
    
    var themeTextColor: Color {
        isDarkMode ? Color.white : Color(white: 0.08)
    }
    
    var themeSubtextColor: Color {
        isDarkMode ? Color.white.opacity(0.65) : Color.black.opacity(0.55)
    }
    
    var themeGlassBackground: Color {
        isDarkMode ? Color(white: 0.16).opacity(0.85) : Color.white.opacity(0.92)
    }
    
    var themeBorderColor: Color {
        isDarkMode ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    // ОБРАНІ ФІЛЬМИ
    var favoritesList: [String] {
        favoritesKeysString.split(separator: ",").map { String($0) }
    }
    
    func isFavorite(movieKey: String) -> Bool {
        favoritesList.contains(movieKey)
    }
    
    func toggleFavorite(movieKey: String) {
        var current = favoritesList
        if current.contains(movieKey) {
            current.removeAll { $0 == movieKey }
        } else {
            current.append(movieKey)
        }
        favoritesKeysString = current.joined(separator: ",")
    }

    // Фільтрація каталогу за рубрикою
    var filteredMovies: [MovieItem] {
        if selectedCategory == "all" {
            return movieCatalog
        } else {
            return movieCatalog.filter { $0.category == selectedCategory }
        }
    }
    
    // Результати пошуку
    var searchResults: [MovieItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty { return [] }
        return movieCatalog.filter { item in
            let titleUA = texts["ua"]?["\(item.key)_title"]?.lowercased() ?? ""
            let titleEN = texts["en"]?["\(item.key)_title"]?.lowercased() ?? ""
            let genreUA = texts["ua"]?["\(item.key)_genre"]?.lowercased() ?? ""
            let directorUA = texts["ua"]?["\(item.key)_director"]?.lowercased() ?? ""
            return titleUA.contains(query) || titleEN.contains(query) || genreUA.contains(query) || directorUA.contains(query)
        }
    }

    var formattedSessionTime: String {
        let minutes = sessionRemainingSeconds / 60
        let seconds = sessionRemainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // =============================================================
    // ГОЛОВНЕ ТІЛО В'Ю (BODY)
    // =============================================================
    var body: some View {
        ZStack {
            themeBackground
                .ignoresSafeArea()
            
            if isShowingSplash {
                // 1. АНІМАЦІЙНА ЗАСТАВКА (SPLASH SCREEN)
                splashScreenView
                    .transition(.opacity)
                    .zIndex(10)
            } else {
                // 2. ГОЛОВНИЙ ЕКРАН З ТАБАМИ
                ZStack(alignment: .bottom) {
                    Group {
                        switch selectedTab {
                        case "home":
                            homeView
                        case "search":
                            searchView
                        case "library":
                            favoritesView
                        case "store":
                            storeView
                        default:
                            homeView
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // ПЛАВАЮЧИЙ ТАБ-БАР
                    floatingTabBar
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onReceive(sessionTimer) { _ in
            if isSessionActive && sessionRemainingSeconds > 0 {
                sessionRemainingSeconds -= 1
                if sessionRemainingSeconds == 0 {
                    currentUser = nil
                    isSessionActive = false
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                splashScale = 1.0
                splashOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    isShowingSplash = false
                }
            }
        }
        // МОДАЛЬНІ ВІКНА
        .sheet(isPresented: $showAuthModal) {
            AuthModalView(
                database: database,
                currentUser: $currentUser,
                isSessionActive: $isSessionActive,
                sessionRemainingSeconds: $sessionRemainingSeconds,
                isDarkMode: isDarkMode,
                onDismiss: { showAuthModal = false }
            )
        }
        .sheet(isPresented: $showProfileModal) {
            ProfileSettingsModalView(
                currentUser: $currentUser,
                isDarkMode: $isDarkMode,
                currentLanguage: $currentLanguage,
                sessionTimeFormatted: formattedSessionTime,
                isSessionActive: isSessionActive,
                onOpenAuth: {
                    showProfileModal = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showAuthModal = true
                    }
                },
                onOpenAdminPanel: {
                    showProfileModal = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showAdminAddMovieModal = true
                    }
                },
                onLogout: {
                    currentUser = nil
                    isSessionActive = false
                    showProfileModal = false
                }
            )
        }
        .sheet(isPresented: $showDetailScreen) {
            DetailReviewsView(
                movieKey: selectedMovie,
                texts: texts[currentLanguage] ?? [:],
                comments: commentsByMovie[selectedMovie] ?? [],
                currentUser: currentUser,
                isDarkMode: isDarkMode,
                onAddComment: { author, text in
                    let newC = MovieComment(
                        author: author,
                        text: text,
                        time: getCurrentTimeString(),
                        isAdmin: currentUser?.role == .admin
                    )
                    commentsByMovie[selectedMovie, default: []].append(newC)
                },
                onDeleteComment: { commentId in
                    commentsByMovie[selectedMovie]?.removeAll { $0.id == commentId }
                }
            )
        }
        .sheet(isPresented: $showMovieSummarySheet) {
            MovieSynopsisSheetView(
                movieKey: selectedMovie,
                texts: texts[currentLanguage] ?? [:],
                isFav: isFavorite(movieKey: selectedMovie),
                isDarkMode: isDarkMode,
                onToggleFavorite: {
                    toggleFavorite(movieKey: selectedMovie)
                },
                onOpenReviews: {
                    showMovieSummarySheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showDetailScreen = true
                    }
                }
            )
        }
        .sheet(isPresented: $showAdminAddMovieModal) {
            AdminAddMovieSheetView(
                isDarkMode: isDarkMode,
                onAddMovie: { newKey, newCat in
                    let nextId = "\(movieCatalog.count + 1)"
                    let item = MovieItem(id: nextId, key: newKey, category: newCat, watchProgress: 0.1, duration: "2 год 00 хв")
                    movieCatalog.append(item)
                    showAdminAddMovieModal = false
                }
            )
        }
    }

// АНІМАЦІЙНА ЗАСТАВКА (SPLASH SCREEN)
    var splashScreenView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            RadialGradient(
                gradient: Gradient(colors: [Color.yellow.opacity(0.45), Color.red.opacity(0.35), Color.clear]),
                center: .center,
                startRadius: 20,
                endRadius: 280
            )
            .ignoresSafeArea()
            
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange, Color.red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 110, height: 110)
                        .shadow(color: Color.yellow.opacity(0.6), radius: 25, x: 0, y: 10)
                    
                    Image(systemName: "film.stack.fill")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundColor(.black)
                }
                .scaleEffect(splashScale)
                
                VStack(spacing: 8) {
                    Text("LUMIÈRE")
                        .font(.system(size: 38, weight: .black, design: .serif))
                        .tracking(8)
                        .foregroundColor(.white)
                        .shadow(color: Color.yellow.opacity(0.4), radius: 15, x: 0, y: 5)
                    
                    Text("CINEMATIC UNIVERSE")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .tracking(5)
                        .foregroundColor(Color.yellow.opacity(0.9))
                }
                .opacity(splashOpacity)
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            isShowingSplash = false
                        }
                    }) {
                        Text("Пропустити ›")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 50)
                }
                Spacer()
            }
        }
    }

    // =============================================================
    // 2. ГОЛОВНА СТОРІНКА «ДОМІВКА» (APPLE TV СТИЛЬ)
    // =============================================================
    var homeView: some View {
        VStack(spacing: 0) {
            // ВЕРХНІЙ БАР: ЛОГОТИП + МОВА + АВТОРИЗАЦІЯ + ТЕМА
            topNavigationBar
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(themeBackground)
                .zIndex(10)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // ---------------------------------------------------------
                    // HERO BANNER (ГОЛОВНИЙ ВЕЛИКИЙ БАНЕР ЯК TED LASSO)
                    // ---------------------------------------------------------
                    heroFeaturedSection

                    // ---------------------------------------------------------
                    // СЕКЦІЯ: ПРОДОВЖИТИ ПЕРЕГЛЯД (CONTINUE WATCHING)
                    // ---------------------------------------------------------
                    continueWatchingSection

                    // ---------------------------------------------------------
                    // СЕКЦІЯ: ТОП-10 ФІЛЬМІВ У LUMIÈRE (З ВЕЛИКИМИ ЦИФРАМИ 1, 2, 3...)
                    // ---------------------------------------------------------
                    top10Section

                    // ---------------------------------------------------------
                    // СЕКЦІЯ: РУБРИКИ ТА КАТЕГОРІЇ (ВИМОГА ЛАБ 6)
                    // ---------------------------------------------------------
                    categoriesCatalogSection
                    
                    // Відступ під нижній TabBar
                    Spacer().frame(height: 110)
                }
            }
        }
    }

    // ВЕРХНІЙ БАР НАВІГАЦІЇ ТА АВТОРИЗАЦІЇ (ЧІТКИЙ КЛІК ТА ЗАКРІПЛЕННЯ)
    var topNavigationBar: some View {
        HStack(alignment: .center, spacing: 8) {
            // Логотип
            HStack(spacing: 6) {
                Image(systemName: "film.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.yellow)
                Text(texts[currentLanguage]?["app_title"] ?? "Lumière")
                    .font(.system(size: 24, weight: .black, design: .serif))
                    .foregroundColor(themeTextColor)
            }
            
            Spacer()
            
            // 1. ПЕРЕМИКАЧ МОВИ (UA / EN)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentLanguage = (currentLanguage == "ua") ? "en" : "ua"
                }
            }) {
                Text(currentLanguage == "ua" ? "🇺🇦 UA" : "🇬🇧 EN")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(themeTextColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(themeGlassBackground)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(themeBorderColor, lineWidth: 1))
            }
            .buttonStyle(.plain)
            
            // 2. ШВИДКИЙ ПЕРЕМИКАЧ ТЕМИ (СВІТЛА / ТЕМНА)
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    isDarkMode.toggle()
                }
            }) {
                Image(systemName: isDarkMode ? "moon.stars.fill" : "sun.max.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isDarkMode ? .yellow : .orange)
                    .padding(7)
                    .background(themeGlassBackground)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(themeBorderColor, lineWidth: 1))
            }
            .buttonStyle(.plain)

            // 3. АВТОРИЗАЦІЯ НА ГОЛОВНОМУ ЕКРАНІ
            if let user = currentUser {
                Button(action: { showProfileModal = true }) {
                    HStack(spacing: 5) {
                        if user.role == .admin {
                            Text("👑 ADMIN")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.yellow)
                                .cornerRadius(6)
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.yellow)
                            Text(user.name)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(themeTextColor)
                        }
                        
                        Text("⏳ \(formattedSessionTime)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(sessionRemainingSeconds < 60 ? .red : .yellow)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(themeGlassBackground)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(themeBorderColor, lineWidth: 1))
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { showAuthModal = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 11))
                        Text(texts[currentLanguage]?["login_btn"] ?? "Увійти")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.yellow)
                    .clipShape(Capsule())
                    .shadow(color: Color.yellow.opacity(0.4), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    var heroFeaturedSection: some View {
        let title = texts[currentLanguage]?["\(selectedMovie)_title"] ?? "Одіссея"
        let genre = texts[currentLanguage]?["\(selectedMovie)_genre"] ?? "Фантастика"
        let year = texts[currentLanguage]?["\(selectedMovie)_year"] ?? "2026"
        let rating = texts[currentLanguage]?["\(selectedMovie)_rating"] ?? "9.2"
        let desc = texts[currentLanguage]?["\(selectedMovie)_desc"] ?? ""
        let isFav = isFavorite(movieKey: selectedMovie)

        return VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Image(selectedMovie)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 440)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .contentShape(Rectangle())
                
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        Color.black.opacity(0.4),
                        Color.black.opacity(0.95)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Text("4K HDR")
                            .font(.system(size: 10, weight: .black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(4)
                        
                        Text(year)
                            .font(.system(size: 11, weight: .bold))
                        
                        Text("•")
                        Text(genre)
                            .font(.system(size: 11, weight: .medium))
                        
                        Text("•")
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                            Text(rating)
                                .font(.system(size: 11, weight: .bold))
                        }
                    }
                    .foregroundColor(.white.opacity(0.9))

                    Text(title.uppercased())
                        .font(.system(size: 32, weight: .black, design: .serif))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .shadow(color: Color.black, radius: 8, x: 0, y: 4)
                    
                    Text(desc)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                        .padding(.bottom, 6)
                    
                    // КНОПКИ ДІЇ: РІВНО ПО ОДНІЙ ІКОНЦІ БЕЗ ДУБЛЮВАННЯ
                    HStack(spacing: 12) {
                        Button(action: {
                            showMovieSummarySheet = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 15))
                                Text(texts[currentLanguage]?["btn_play"] ?? "Дивитися")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
                        }
                        
                        Button(action: {
                            withAnimation(.spring()) {
                                toggleFavorite(movieKey: selectedMovie)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: isFav ? "checkmark" : "plus")
                                    .font(.system(size: 15, weight: .bold))
                                Text(isFav ? (texts[currentLanguage]?["btn_favorite_remove"] ?? "В обраному") : (texts[currentLanguage]?["btn_favorite_add"] ?? "В обране"))
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(isFav ? Color.yellow.opacity(0.4) : Color.white.opacity(0.25))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isFav ? Color.yellow : Color.white.opacity(0.3), lineWidth: 1.5)
                            )
                        }
                    }
                }
                .padding(20)
            }
            .cornerRadius(24)
            .padding(.horizontal, 16)
            .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)

            HStack(spacing: 6) {
                ForEach(movieCatalog.prefix(5), id: \.key) { m in
                    Circle()
                        .fill(m.key == selectedMovie ? Color.yellow : themeTextColor.opacity(0.25))
                        .frame(width: m.key == selectedMovie ? 18 : 6, height: 6)
                        .animation(.spring(), value: selectedMovie)
                        .onTapGesture {
                            selectedMovie = m.key
                        }
                }
            }
            .padding(.top, 12)
        }
    }

    var continueWatchingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(texts[currentLanguage]?["section_continue"] ?? "Продовжити перегляд")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(themeTextColor)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(themeSubtextColor)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(movieCatalog.filter { $0.watchProgress > 0 }, id: \.key) { movie in
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack(alignment: .bottomLeading) {
                                Image(movie.key)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 220, height: 130)
                                    .clipped()
                                    .cornerRadius(14)
                                    .contentShape(Rectangle())
                                
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.8)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .cornerRadius(14)
                                
                                HStack {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
                                    Text(movie.duration)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .padding(10)
                                
                                GeometryReader { geo in
                                    VStack {
                                        Spacer()
                                        ZStack(alignment: .leading) {
                                            Rectangle()
                                                .fill(Color.white.opacity(0.3))
                                                .frame(height: 4)
                                            Rectangle()
                                                .fill(Color.yellow)
                                                .frame(width: geo.size.width * CGFloat(movie.watchProgress), height: 4)
                                        }
                                    }
                                }
                                .cornerRadius(14)
                            }
                            .frame(width: 220, height: 130)
                            
                            Text(texts[currentLanguage]?["\(movie.key)_title"] ?? "")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(themeTextColor)
                                .lineLimit(1)
                        }
                        .onTapGesture {
                            selectedMovie = movie.key
                            showMovieSummarySheet = true
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    var top10Section: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(texts[currentLanguage]?["section_top10"] ?? "Топ-10 фільмів у Lumière")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(themeTextColor)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(themeSubtextColor)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 22) {
                    ForEach(Array(movieCatalog.prefix(6).enumerated()), id: \.element.key) { index, movie in
                        HStack(alignment: .bottom, spacing: -25) {
                            Text("\(index + 1)")
                                .font(.system(size: 95, weight: .black, design: .rounded))
                                .foregroundColor(themeSubtextColor.opacity(0.35))
                                .offset(y: 12)
                                .zIndex(0)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Image(movie.key)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 135, height: 195)
                                    .clipped()
                                    .cornerRadius(14)
                                    .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                                    .contentShape(Rectangle())
                                
                                Text(texts[currentLanguage]?["\(movie.key)_title"] ?? "")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(themeTextColor)
                                    .lineLimit(1)
                                    .frame(width: 135, alignment: .leading)
                                
                                Text(texts[currentLanguage]?["\(movie.key)_genre"] ?? "")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(themeSubtextColor)
                                    .lineLimit(1)
                                    .frame(width: 135, alignment: .leading)
                            }
                            .zIndex(1)
                            .onTapGesture {
                                selectedMovie = movie.key
                                showMovieSummarySheet = true
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    var categoriesCatalogSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(texts[currentLanguage]?["category_label"] ?? "Рубрика:")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(themeTextColor)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryFilterChip(title: texts[currentLanguage]?["cat_all"] ?? "Усі", key: "all")
                    categoryFilterChip(title: texts[currentLanguage]?["cat_sci_fi"] ?? "Фантастика", key: "sci_fi")
                    categoryFilterChip(title: texts[currentLanguage]?["cat_adventure"] ?? "Пригоди", key: "adventure")
                    categoryFilterChip(title: texts[currentLanguage]?["cat_drama"] ?? "Драма", key: "drama")
                    categoryFilterChip(title: texts[currentLanguage]?["cat_animation"] ?? "Анімація", key: "animation")
                    categoryFilterChip(title: texts[currentLanguage]?["cat_comedy"] ?? "Комедія", key: "comedy")
                }
                .padding(.horizontal, 20)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(filteredMovies, id: \.key) { movie in
                        VStack(alignment: .leading, spacing: 6) {
                            ZStack(alignment: .topTrailing) {
                                Image(movie.key)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 140, height: 200)
                                    .clipped()
                                    .cornerRadius(14)
                                    .contentShape(Rectangle())
                                
                                Button(action: {
                                    withAnimation(.spring()) {
                                        toggleFavorite(movieKey: movie.key)
                                    }
                                }) {
                                    Image(systemName: isFavorite(movieKey: movie.key) ? "heart.fill" : "heart")
                                        .font(.system(size: 16))
                                        .foregroundColor(isFavorite(movieKey: movie.key) ? .red : .white)
                                        .padding(8)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .padding(8)
                            }
                            
                            Text(texts[currentLanguage]?["\(movie.key)_title"] ?? "")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(themeTextColor)
                                .lineLimit(1)
                                .frame(width: 140, alignment: .leading)
                            
                            HStack {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.yellow)
                                Text(texts[currentLanguage]?["\(movie.key)_rating"] ?? "8.0")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(themeSubtextColor)
                                Spacer()
                                Text(texts[currentLanguage]?["\(movie.key)_year"] ?? "")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(themeSubtextColor)
                            }
                            .frame(width: 140)
                        }
                        .onTapGesture {
                            selectedMovie = movie.key
                            showMovieSummarySheet = true
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    func categoryFilterChip(title: String, key: String) -> some View {
        let isSelected = (selectedCategory == key)
        return Button(action: {
            withAnimation(.spring()) {
                selectedCategory = key
            }
        }) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .black : themeTextColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.yellow : themeGlassBackground)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(themeBorderColor, lineWidth: 1))
        }
    }

    // =============================================================
    // 3. ВКЛАДКА «ПОШУК» (SEARCH - APPLE TV СТИЛЬ)
    // =============================================================
    var searchView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                
                HStack {
                    Text(texts[currentLanguage]?["tab_search"] ?? "Пошук")
                        .font(.system(size: 32, weight: .black, design: .serif))
                        .foregroundColor(themeTextColor)
                    Spacer()
                    Button(action: { showProfileModal = true }) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.yellow)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(themeSubtextColor)
                    
                    TextField(texts[currentLanguage]?["search_placeholder"] ?? "Фільми, жанри, режисери...", text: $searchText)
                        .font(.system(size: 16))
                        .foregroundColor(themeTextColor)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(themeSubtextColor)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(themeCardBackground)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(themeBorderColor, lineWidth: 1))
                .padding(.horizontal, 20)
                
                if searchText.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(texts[currentLanguage]?["search_categories"] ?? "Жанрові рубрики")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(themeTextColor)
                            .padding(.horizontal, 20)
                        
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                            ForEach(genreTiles) { tile in
                                Button(action: {
                                    selectedCategory = tile.key
                                    selectedTab = "home"
                                }) {
                                    ZStack(alignment: .bottomLeading) {
                                        LinearGradient(colors: tile.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                                            .frame(height: 110)
                                            .cornerRadius(16)
                                        
                                        VStack(alignment: .leading, spacing: 6) {
                                            Image(systemName: tile.icon)
                                                .font(.system(size: 24))
                                                .foregroundColor(.white)
                                            
                                            Text(currentLanguage == "ua" ? tile.nameUA : tile.nameEN)
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                        .padding(14)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Знайдено: \(searchResults.count)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(themeSubtextColor)
                            .padding(.horizontal, 20)
                        
                        if searchResults.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass.circle")
                                    .font(.system(size: 50))
                                    .foregroundColor(themeSubtextColor)
                                Text(texts[currentLanguage]?["search_no_results"] ?? "Нічого не знайдено")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(themeSubtextColor)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(searchResults, id: \.key) { movie in
                                    HStack(spacing: 14) {
                                        Image(movie.key)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 75, height: 110)
                                            .clipped()
                                            .cornerRadius(10)
                                            .contentShape(Rectangle())
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(texts[currentLanguage]?["\(movie.key)_title"] ?? "")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(themeTextColor)
                                            
                                            Text(texts[currentLanguage]?["\(movie.key)_genre"] ?? "")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(themeSubtextColor)
                                            
                                            HStack(spacing: 8) {
                                                Text(texts[currentLanguage]?["\(movie.key)_year"] ?? "")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(themeSubtextColor)
                                                
                                                HStack(spacing: 3) {
                                                    Image(systemName: "star.fill")
                                                        .font(.system(size: 10))
                                                        .foregroundColor(.yellow)
                                                    Text(texts[currentLanguage]?["\(movie.key)_rating"] ?? "")
                                                        .font(.system(size: 12, weight: .bold))
                                                        .foregroundColor(themeTextColor)
                                                }
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            selectedMovie = movie.key
                                            showMovieSummarySheet = true
                                        }) {
                                            Image(systemName: "chevron.right.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(.yellow)
                                        }
                                    }
                                    .padding(12)
                                    .background(themeCardBackground)
                                    .cornerRadius(14)
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(themeBorderColor, lineWidth: 1))
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                
                Spacer().frame(height: 120)
            }
        }
    }

    // =============================================================
    // 4. ВКЛАДКА «ОБРАНЕ» (FAVORITES / LIBRARY)
    // =============================================================
    var favoritesView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(texts[currentLanguage]?["section_favorites"] ?? "Моє обране")
                        .font(.system(size: 32, weight: .black, design: .serif))
                        .foregroundColor(themeTextColor)
                    Spacer()
                    Text("\(favoritesList.count)")
                        .font(.system(size: 14, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.yellow)
                        .foregroundColor(.black)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                if favoritesList.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "heart.slash.fill")
                            .font(.system(size: 60))
                            .foregroundColor(themeSubtextColor.opacity(0.5))
                            .padding(.top, 60)
                        
                        Text(texts[currentLanguage]?["favorites_empty_title"] ?? "Список обраного порожній")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(themeTextColor)
                        
                        Text(texts[currentLanguage]?["favorites_empty_desc"] ?? "Додавайте фільми, щоб не загубити!")
                            .font(.system(size: 14))
                            .foregroundColor(themeSubtextColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button(action: { selectedTab = "home" }) {
                            Text("Перейти до каталогу")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.yellow)
                                .cornerRadius(12)
                        }
                        .padding(.top, 10)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 16) {
                        ForEach(favoritesList, id: \.self) { movieKey in
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .topTrailing) {
                                    Image(movieKey)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 220)
                                        .frame(maxWidth: .infinity)
                                        .clipped()
                                        .cornerRadius(14)
                                        .contentShape(Rectangle())
                                    
                                    Button(action: {
                                        withAnimation(.spring()) {
                                            toggleFavorite(movieKey: movieKey)
                                        }
                                    }) {
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.red)
                                            .padding(8)
                                            .background(Color.black.opacity(0.65))
                                            .clipShape(Circle())
                                    }
                                    .padding(8)
                                }
                                
                                Text(texts[currentLanguage]?["\(movieKey)_title"] ?? "")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(themeTextColor)
                                    .lineLimit(1)
                                
                                HStack {
                                    Text(texts[currentLanguage]?["\(movieKey)_year"] ?? "")
                                        .font(.system(size: 12))
                                        .foregroundColor(themeSubtextColor)
                                    Spacer()
                                    HStack(spacing: 2) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(.yellow)
                                        Text(texts[currentLanguage]?["\(movieKey)_rating"] ?? "")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(themeTextColor)
                                    }
                                }
                            }
                            .onTapGesture {
                                selectedMovie = movieKey
                                showMovieSummarySheet = true
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer().frame(height: 120)
            }
        }
    }

    // =============================================================
    // 5. ВКЛАДКА «КВИТКИ» (STORE)
    // =============================================================
    var storeView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                HStack {
                    Text(texts[currentLanguage]?["tab_store"] ?? "Квитки та кінотеатри")
                        .font(.system(size: 28, weight: .black, design: .serif))
                        .foregroundColor(themeTextColor)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                VStack(spacing: 16) {
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                        .padding(.top, 30)
                    
                    Text("Бронювання квитків Lumière IMAX")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(themeTextColor)
                    
                    Text("Обирайте найкращі місця у кінозалах вашого міста прямо в додатку!")
                        .font(.system(size: 14))
                        .foregroundColor(themeSubtextColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    
                    Button(action: {
                        selectedMovie = "movie1"
                        showMovieSummarySheet = true
                    }) {
                        Text("Переглянути розклад на «Одіссея 2026»")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.yellow)
                            .cornerRadius(12)
                    }
                    .padding(.top, 10)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(themeCardBackground)
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(themeBorderColor, lineWidth: 1))
                .padding(.horizontal, 20)
                
                Spacer().frame(height: 120)
            }
        }
    }

    // =============================================================
    // 6. ПЛАВАЮЧИЙ ТАБ-БАР
    // =============================================================
    var floatingTabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: texts[currentLanguage]?["tab_home"] ?? "Домівка", icon: "house.fill", tag: "home")
            tabButton(title: texts[currentLanguage]?["tab_search"] ?? "Пошук", icon: "magnifyingglass", tag: "search")
            tabButton(title: texts[currentLanguage]?["tab_library"] ?? "Обране", icon: "heart.fill", tag: "library", badgeCount: favoritesList.count)
            tabButton(title: texts[currentLanguage]?["tab_store"] ?? "Квитки", icon: "ticket.fill", tag: "store")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(themeGlassBackground)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(themeBorderColor, lineWidth: 1))
        .shadow(color: Color.black.opacity(isDarkMode ? 0.4 : 0.15), radius: 15, x: 0, y: 6)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    func tabButton(title: String, icon: String, tag: String, badgeCount: Int = 0) -> some View {
        let isSelected = (selectedTab == tag)
        return Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedTab = tag
            }
        }) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: isSelected ? .bold : .regular))
                    
                    if badgeCount > 0 {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 6, y: -2)
                    }
                }
                
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
            }
            .foregroundColor(isSelected ? .yellow : themeSubtextColor)
            .frame(maxWidth: .infinity)
        }
    }

    func getCurrentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}

// =================================================================
// 7. МОДАЛЬНЕ ВІКНО НАЛАШТУВАНЬ ПРОФІЛЮ ТА ТЕМИ
// =================================================================
struct ProfileSettingsModalView: View {
    @Binding var currentUser: UserAccount?
    @Binding var isDarkMode: Bool
    @Binding var currentLanguage: String
    let sessionTimeFormatted: String
    let isSessionActive: Bool
    
    let onOpenAuth: () -> Void
    let onOpenAdminPanel: () -> Void
    let onLogout: () -> Void
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color(red: 0.95, green: 0.95, blue: 0.97))
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    
                    // КАРТКА КОРИСТУВАЧА (3 РОЛІ)
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: currentUser != nil ? [Color.yellow, Color.orange] : [Color.gray.opacity(0.4), Color.gray],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 75, height: 75)
                            
                            if let user = currentUser {
                                if user.role == .admin {
                                    Text("👑")
                                        .font(.system(size: 34))
                                } else {
                                    Text(String(user.name.prefix(1)).uppercased())
                                        .font(.system(size: 32, weight: .black))
                                        .foregroundColor(.black)
                                }
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 34))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        if let user = currentUser {
                            VStack(spacing: 4) {
                                Text(user.name)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(isDarkMode ? .white : .black)
                                
                                HStack(spacing: 6) {
                                    Text(user.role.rawValue)
                                        .font(.system(size: 11, weight: .black))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(user.role == .admin ? Color.yellow : Color.blue)
                                        .foregroundColor(user.role == .admin ? .black : .white)
                                        .cornerRadius(6)
                                    
                                    if isSessionActive {
                                        Text("⏳ \(sessionTimeFormatted)")
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundColor(.yellow)
                                    }
                                }
                            }
                        } else {
                            VStack(spacing: 4) {
                                Text("Гість (Неавторизований)")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(isDarkMode ? .white : .black)
                                Text("Увійдіть для доступу до рецензій та ролей")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(isDarkMode ? Color(white: 0.15) : Color.white)
                    .cornerRadius(18)
                    
                    // БЛОК ЗМІНИ ТЕМИ (СВІТЛА / ТЕМНА)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ОФОРМЛЕННЯ ТА ТЕМА")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 4)
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                withAnimation {
                                    isDarkMode = false
                                }
                            }) {
                                HStack {
                                    Image(systemName: "sun.max.fill")
                                        .foregroundColor(.orange)
                                    Text("Світла")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(!isDarkMode ? Color.yellow.opacity(0.3) : (isDarkMode ? Color(white: 0.2) : Color(white: 0.9)))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(!isDarkMode ? Color.yellow : Color.clear, lineWidth: 2)
                                )
                                .foregroundColor(isDarkMode ? .white : .black)
                            }
                            
                            Button(action: {
                                withAnimation {
                                    isDarkMode = true
                                }
                            }) {
                                HStack {
                                    Image(systemName: "moon.stars.fill")
                                        .foregroundColor(.purple)
                                    Text("Темна")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isDarkMode ? Color.yellow.opacity(0.3) : (isDarkMode ? Color(white: 0.2) : Color(white: 0.9)))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isDarkMode ? Color.yellow : Color.clear, lineWidth: 2)
                                )
                                .foregroundColor(isDarkMode ? .white : .black)
                            }
                        }
                    }
                    .padding(16)
                    .background(isDarkMode ? Color(white: 0.15) : Color.white)
                    .cornerRadius(18)
                    
                    // ДІЇ КОРИСТУВАЧА ТА АДМІНА
                    VStack(spacing: 10) {
                        if currentUser == nil {
                            Button(action: onOpenAuth) {
                                HStack {
                                    Image(systemName: "lock.open.fill")
                                    Text("Увійти або зареєструватися")
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.yellow)
                                .cornerRadius(12)
                            }
                        } else {
                            if currentUser?.role == .admin {
                                Button(action: onOpenAdminPanel) {
                                    HStack {
                                        Image(systemName: "plus.film.fill")
                                        Text("Додати новий фільм (Адмін)")
                                    }
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(Color.purple)
                                    .cornerRadius(12)
                                }
                            }
                            
                            Button(action: onLogout) {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text("Вийти з акаунту")
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(isDarkMode ? Color(white: 0.2) : Color(white: 0.9))
                                .cornerRadius(12)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Профіль та налаштування")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                        .foregroundColor(.yellow)
                }
            }
        }
    }
}

// =================================================================
// 8. СИНОПСИС ФІЛЬМУ (КОРОТКИЙ ЗМІСТ - ВИМОГА ЛАБ 6)
// =================================================================
struct MovieSynopsisSheetView: View {
    let movieKey: String
    let texts: [String: String]
    let isFav: Bool
    let isDarkMode: Bool
    let onToggleFavorite: () -> Void
    let onOpenReviews: () -> Void
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color(red: 0.95, green: 0.95, blue: 0.97))
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        ZStack(alignment: .bottomLeading) {
                            Image(movieKey)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 320)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .contentShape(Rectangle())
                            
                            LinearGradient(
                                gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.85)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(texts["\(movieKey)_title"] ?? "")
                                    .font(.system(size: 26, weight: .black, design: .serif))
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 8) {
                                    Text(texts["\(movieKey)_year"] ?? "")
                                        .font(.system(size: 13, weight: .bold))
                                    Text("•")
                                    Text(texts["\(movieKey)_genre"] ?? "")
                                        .font(.system(size: 13, weight: .medium))
                                    Text("•")
                                    HStack(spacing: 3) {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                        Text(texts["\(movieKey)_rating"] ?? "")
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                }
                                .foregroundColor(.white.opacity(0.9))
                            }
                            .padding(16)
                        }
                        
                        VStack(alignment: .leading, spacing: 18) {
                            
                            HStack(spacing: 12) {
                                Button(action: onToggleFavorite) {
                                    HStack {
                                        Image(systemName: isFav ? "heart.fill" : "heart")
                                            .foregroundColor(isFav ? .red : .yellow)
                                        Text(isFav ? "В обраному" : "В обране")
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                    .foregroundColor(isDarkMode ? .white : .black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(isDarkMode ? Color(white: 0.18) : Color.white)
                                    .cornerRadius(12)
                                }
                                
                                Button(action: onOpenReviews) {
                                    HStack {
                                        Image(systemName: "bubble.left.and.bubble.right.fill")
                                            .foregroundColor(.yellow)
                                        Text("Відгуки")
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                    .foregroundColor(isDarkMode ? .white : .black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(isDarkMode ? Color(white: 0.18) : Color.white)
                                    .cornerRadius(12)
                                }
                            }
                            
                            // РЕЖИСЕР
                            VStack(alignment: .leading, spacing: 8) {
                                Text("РЕЖИСЕР")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundColor(.gray)
                                
                                Text(texts["\(movieKey)_director"] ?? "Крістофер Нолан")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(isDarkMode ? .white : .black)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(isDarkMode ? Color(white: 0.15) : Color.white)
                            .cornerRadius(14)
                            
                            // СИНОПСИС
                            VStack(alignment: .leading, spacing: 10) {
                                Text("КОРОТКИЙ ЗМІСТ (СИНОПСИС)")
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundColor(.yellow)
                                
                                Text(texts["\(movieKey)_synopsis"] ?? texts["\(movieKey)_desc"] ?? "Опис фільму незабаром з'явиться.")
                                    .font(.system(size: 15, weight: .regular))
                                    .lineSpacing(6)
                                    .foregroundColor(isDarkMode ? Color.white.opacity(0.9) : Color.black.opacity(0.85))
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(isDarkMode ? Color(white: 0.15) : Color.white)
                            .cornerRadius(16)
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer().frame(height: 30)
                    }
                }
            }
            .navigationTitle("Про фільм")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрити") { dismiss() }
                        .foregroundColor(.yellow)
                }
            }
        }
    }
}

// =================================================================
// 9. АВТОРИЗАЦІЯ (ЛОГІН ТА РЕЄСТРАЦІЯ)
// =================================================================
struct AuthModalView: View {
    @ObservedObject var database: CloudMovieDatabase
    @Binding var currentUser: UserAccount?
    @Binding var isSessionActive: Bool
    @Binding var sessionRemainingSeconds: Int
    let isDarkMode: Bool
    let onDismiss: () -> Void
    
    @State private var authMode: String = "login"
    @State private var inputName: String = ""
    @State private var inputLogin: String = ""
    @State private var inputPass: String = ""
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false

    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color(red: 0.95, green: 0.95, blue: 0.97))
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        HStack(spacing: 0) {
                            Button(action: { authMode = "login" }) {
                                Text("Вхід")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(authMode == "login" ? .black : (isDarkMode ? .white : .black))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(authMode == "login" ? Color.yellow : Color.clear)
                                    .cornerRadius(10)
                            }
                            
                            Button(action: { authMode = "register" }) {
                                Text("Новий акаунт")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(authMode == "register" ? .black : (isDarkMode ? .white : .black))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(authMode == "register" ? Color.yellow : Color.clear)
                                    .cornerRadius(10)
                            }
                        }
                        .padding(4)
                        .background(isDarkMode ? Color(white: 0.2) : Color(white: 0.88))
                        .cornerRadius(12)
                        
                        VStack(spacing: 14) {
                            if authMode == "register" {
                                customTextField(placeholder: "Ваше ім'я", text: $inputName, icon: "person")
                            }
                            customTextField(placeholder: "Логін", text: $inputLogin, icon: "at")
                            customSecureField(placeholder: "Пароль", text: $inputPass, icon: "lock")
                        }
                        
                        Button(action: performAuth) {
                            Text(authMode == "login" ? "Увійти в акаунт" : "Створити акаунт")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.yellow)
                                .cornerRadius(12)
                        }
                        
                        VStack(spacing: 8) {
                            Text("Швидкий вхід:")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            
                            HStack(spacing: 12) {
                                Button("Богдана (User)") {
                                    inputLogin = "bohdana"
                                    inputPass = "123"
                                    performAuth()
                                }
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isDarkMode ? Color(white: 0.2) : Color.white)
                                .foregroundColor(.yellow)
                                .cornerRadius(8)
                                
                                Button("👑 Admin") {
                                    inputLogin = "admin"
                                    inputPass = "admin123"
                                    performAuth()
                                }
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isDarkMode ? Color(white: 0.2) : Color.white)
                                .foregroundColor(.yellow)
                                .cornerRadius(8)
                            }
                        }
                        .padding(.top, 10)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(authMode == "login" ? "Авторизація" : "Реєстрація")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Скасувати") { onDismiss() }
                        .foregroundColor(.yellow)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Повідомлення"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    func customTextField(placeholder: String, text: Binding<String>, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.yellow)
                .frame(width: 24)
            TextField(placeholder, text: text)
                .foregroundColor(isDarkMode ? .white : .black)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
        }
        .padding(14)
        .background(isDarkMode ? Color(white: 0.16) : Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }
    
    func customSecureField(placeholder: String, text: Binding<String>, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.yellow)
                .frame(width: 24)
            SecureField(placeholder, text: text)
                .foregroundColor(isDarkMode ? .white : .black)
                .textInputAutocapitalization(.never)
        }
        .padding(14)
        .background(isDarkMode ? Color(white: 0.16) : Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }
    
    func performAuth() {
        if authMode == "login" {
            if let user = database.authenticate(login: inputLogin, pass: inputPass) {
                currentUser = user
                isSessionActive = true
                sessionRemainingSeconds = 300
                onDismiss()
            } else {
                alertMessage = "Невірний логін або пароль!"
                showAlert = true
            }
        } else {
            if inputName.isEmpty || inputLogin.isEmpty || inputPass.isEmpty {
                alertMessage = "Заповніть усі поля!"
                showAlert = true
                return
            }
            let res = database.register(name: inputName, login: inputLogin, pass: inputPass)
            if res.success {
                if let user = database.authenticate(login: inputLogin, pass: inputPass) {
                    currentUser = user
                    isSessionActive = true
                    sessionRemainingSeconds = 300
                    onDismiss()
                }
            } else {
                alertMessage = res.message
                showAlert = true
            }
        }
    }
}

// =================================================================
// 10. ПАНЕЛЬ ДОДАВАННЯ ФІЛЬМУ (АДМІНІСТРАТОР)
// =================================================================
struct AdminAddMovieSheetView: View {
    let isDarkMode: Bool
    let onAddMovie: (String, String) -> Void
    
    @State private var selectedKey: String = "movie1"
    @State private var selectedCategory: String = "sci_fi"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color(red: 0.95, green: 0.95, blue: 0.97))
                    .ignoresSafeArea()
                
                Form {
                    Section(header: Text("Параметри нового фільму")) {
                        Picker("Шаблон постера", selection: $selectedKey) {
                            Text("Одіссея (movie1)").tag("movie1")
                            Text("Дюна (movie2)").tag("movie2")
                            Text("Інтерстеллар (movie3)").tag("movie3")
                            Text("Ваяна (movie7)").tag("movie7")
                        }
                        
                        Picker("Рубрика фільму", selection: $selectedCategory) {
                            Text("Фантастика").tag("sci_fi")
                            Text("Пригоди").tag("adventure")
                            Text("Драма").tag("drama")
                            Text("Комедія").tag("comedy")
                            Text("Анімація").tag("animation")
                        }
                    }
                    
                    Section {
                        Button("Опублікувати в каталозі") {
                            onAddMovie(selectedKey, selectedCategory)
                        }
                        .foregroundColor(.yellow)
                    }
                }
            }
            .navigationTitle("Панель Адміністратора")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрити") { dismiss() }
                        .foregroundColor(.yellow)
                }
            }
        }
    }
}

// =================================================================
// 11. СТРІЧКА ВІДГУКІВ ТА ВИДАЛЕННЯ
// =================================================================
struct DetailReviewsView: View {
    let movieKey: String
    let texts: [String: String]
    let comments: [MovieComment]
    let currentUser: UserAccount?
    let isDarkMode: Bool
    let onAddComment: (String, String) -> Void
    let onDeleteComment: (UUID) -> Void
    
    @State private var textInput: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color(red: 0.95, green: 0.95, blue: 0.97))
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if comments.isEmpty {
                                Text("Ще немає коментарів. Залиште перший!")
                                    .foregroundColor(.gray)
                                    .padding(.top, 40)
                            } else {
                                ForEach(comments) { comment in
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 6) {
                                                Text(comment.author)
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(isDarkMode ? .white : .black)
                                                
                                                if comment.isAdmin {
                                                    Text("👑 ADMIN")
                                                        .font(.system(size: 9, weight: .black))
                                                        .padding(.horizontal, 5)
                                                        .padding(.vertical, 2)
                                                        .background(Color.yellow)
                                                        .foregroundColor(.black)
                                                        .cornerRadius(4)
                                                }
                                                
                                                Spacer()
                                                
                                                Text(comment.time)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.gray)
                                            }
                                            
                                            Text(comment.text)
                                                .font(.system(size: 14))
                                                .foregroundColor(isDarkMode ? Color.white.opacity(0.9) : Color.black.opacity(0.85))
                                        }
                                        
                                        if currentUser?.role == .admin || currentUser?.name == comment.author {
                                            Button(action: { onDeleteComment(comment.id) }) {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.red.opacity(0.8))
                                            }
                                            .padding(.leading, 6)
                                        }
                                    }
                                    .padding(14)
                                    .background(isDarkMode ? Color(white: 0.16) : Color.white)
                                    .cornerRadius(14)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                    }
                    
                    HStack(spacing: 10) {
                        TextField("Напишіть відгук...", text: $textInput)
                            .padding(12)
                            .background(isDarkMode ? Color(white: 0.2) : Color.white)
                            .foregroundColor(isDarkMode ? .white : .black)
                            .cornerRadius(12)
                        
                        Button(action: {
                            let trimmed = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            let author = currentUser?.name ?? "Гість"
                            onAddComment(author, trimmed)
                            textInput = ""
                        }) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.black)
                                .padding(12)
                                .background(Color.yellow)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .navigationTitle("Відгуки: \(texts["\(movieKey)_title"] ?? "")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                        .foregroundColor(.yellow)
                }
            }
        }
    }
}
