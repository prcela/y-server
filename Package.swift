import PackageDescription

let package = Package(
    name: "y-server",
    dependencies: [
        .Package(url: "https://github.com/vapor/vapor.git", majorVersion: 1),
        .Package(url: "https://github.com/OpenKitten/MongoKitten.git", majorVersion: 2, minor: 0),
        .Package(url: "https://github.com/IBM-Swift/SwiftyJSON.git", majorVersion: 15)
//        .Package(url: "https://github.com/Zewo/JSON.git", majorVersion: 0, minor: 6),
    ],
    exclude: [
        "Config",
        "Database",
        "Localization",
        "Public",
        "Resources",
        "Tests",
    ]
)

