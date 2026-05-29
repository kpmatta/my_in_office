import CoreLocation
import Foundation
import MapKit
import OSLog

struct AppAlertInfo: Identifiable, Equatable, Error {
    let id = UUID()
    let title: String
    let message: String
}

enum AppDiagnostics {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "InOffice",
        category: "App"
    )

    static func error(_ message: String, error: Error? = nil) {
        if let error {
            logger.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .private)")
        } else {
            logger.error("\(message, privacy: .public)")
        }
    }
}

enum AppUserFeedback {
    static let appStorageUnavailable = AppAlertInfo(
        title: "We couldn't open your saved data",
        message: "Please close and reopen the app. If this keeps happening, reinstall the app or contact support."
    )

    static let locationPermissionNeeded = AppAlertInfo(
        title: "Allow location access first",
        message: "Approve location access, then try using your current workplace again."
    )

    static let locationPermissionDenied = AppAlertInfo(
        title: "Location access is turned off",
        message: "Turn on location access in Settings to use your current workplace and automatic office detection."
    )

    static let addressNotFound = AppAlertInfo(
        title: "We couldn't find that place",
        message: "Try a more complete address or choose a different search result."
    )

    static let addressFallbackNotice = "We saved your current location, but couldn't load the full street address."
    static let autoLogFallbackNotice = "We couldn't auto-log today's visit. You can still mark today manually from the Log tab."

    static let exportUnavailable = AppAlertInfo(
        title: "Couldn't create your backup",
        message: "We hit a problem while preparing your CSV. Please try again in a moment."
    )

    static let deleteUnavailable = AppAlertInfo(
        title: "Couldn't delete your data",
        message: "Nothing was removed. Please try again in a moment."
    )

    static let daySaveUnavailable = AppAlertInfo(
        title: "Couldn't save your day",
        message: "Your change wasn't saved. Please try again."
    )

    static let batchUpdateUnavailable = AppAlertInfo(
        title: "Couldn't update those days",
        message: "Your batch edit didn't finish. Please try again."
    )

    static let locationSearchUnavailable = AppAlertInfo(
        title: "Search is unavailable right now",
        message: "Check your connection and try searching for your workplace again."
    )

    static let locationSelectionUnavailable = AppAlertInfo(
        title: "Couldn't load that place",
        message: "Try selecting the address again in a moment."
    )

    static func locationSelectionUnavailable(for error: Error?) -> AppAlertInfo {
        if isOffline(error) {
            return AppAlertInfo(
                title: "You're offline right now",
                message: "We couldn't finish loading that place. Check your connection and try again."
            )
        }

        return locationSelectionUnavailable
    }

    static func currentLocationUnavailable(for error: Error?) -> AppAlertInfo {
        if isOffline(error) {
            return AppAlertInfo(
                title: "You're offline right now",
                message: "We couldn't fetch your current location. Check your connection and try again."
            )
        }

        return AppAlertInfo(
            title: "Couldn't get your current location",
            message: "Please make sure location services are available, then try again."
        )
    }

    static func addressLookupUnavailable(for error: Error?) -> AppAlertInfo {
        if isOffline(error) {
            return AppAlertInfo(
                title: "You're offline right now",
                message: "We couldn't look up that address. Check your connection and try again."
            )
        }

        return AppAlertInfo(
            title: "Couldn't look up that address",
            message: "Please try again in a moment or search for a different address."
        )
    }

    static func importUnavailable(for error: CSVImporter.ImportError) -> AppAlertInfo {
        switch error {
        case .fileAccessDenied:
            return AppAlertInfo(
                title: "We couldn't open that file",
                message: "Please reselect the CSV file and try again."
            )
        case .fileReadFailed:
            return AppAlertInfo(
                title: "We couldn't read that file",
                message: "Try another copy of the CSV or export it again before importing."
            )
        case .invalidFormat:
            return AppAlertInfo(
                title: "That file doesn't look right",
                message: "Choose a valid InOffice CSV backup and try again."
            )
        case .saveFailed:
            return AppAlertInfo(
                title: "Couldn't import your data",
                message: "No changes were finalized. Please try importing again."
            )
        }
    }

    static func fileSelectionUnavailable(for error: Error) -> AppAlertInfo? {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError {
            return nil
        }

        return AppAlertInfo(
            title: "Couldn't open the file picker",
            message: "Please try choosing the file again."
        )
    }

    private static func isOffline(_ error: Error?) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost, .cannotFindHost:
                return true
            default:
                break
            }
        }

        if let clError = error as? CLError, clError.code == .network {
            return true
        }

        if let mkError = error as? MKError, mkError.code == .serverFailure {
            return true
        }

        let nsError = error as NSError?
        return nsError?.domain == NSURLErrorDomain
    }
}
