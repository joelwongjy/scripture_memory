import Foundation

/// The two bundled editions, resolved through `VerseCatalog` so a remote
/// correction can supersede the bundled JSON. Read once at first access and
/// held for the life of the process — see `VerseCatalog` for why updates are
/// deliberately deferred to the next launch.
var packsNIV84: [Pack] = VerseCatalog.packs(edition: "NIV84", bundledFile: "verseData.json")
var packsNIV11: [Pack] = VerseCatalog.packs(edition: "NIV11", bundledFile: "verseDataNIV11.json")
