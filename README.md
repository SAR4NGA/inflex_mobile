# Inflex_Mobile


A robust Flutter mobile application designed to help users track their finances, manage transactions, and categorize expenses efficiently.

## Features

*   **User Authentication**: Secure login and session management using JWT tokens.
*   **Transaction Management**: Add, view, edit, and delete daily financial transactions.
*   **Category Management**: Organize your incomes and expenses into customizable categories.
*   **Data Import/Export**: Import bulk transactions from CSV files and export your financial data for external use.
*   **Secure Storage**: Safely stores authentication tokens on the device using `flutter_secure_storage`.
*   **REST API Integration**: Seamlessly communicates with a backend server using the `http` package.

## Project Structure

The codebase is organized into a clean architecture within the `lib/` directory:

*   **`core/`**: Core application configurations and constants.
*   **`models/`**: Data models for transactions, categories, and authentication.
*   **`screens/`**: UI screens including `HomeScreen`, `TransactionsScreen`, `CategoriesScreen`, `LoginScreen`, etc.
*   **`services/`**: API clients and business logic (`AuthService`, `TransactionService`, `CategoryService`).
*   **`utils/`**: Helper functions, formatters, and external integrations.

## Tech Stack & Dependencies

*   **Framework**: [Flutter](https://flutter.dev/) (SDK ^3.10.7)
*   **Networking**: `http`
*   **Security**: `flutter_secure_storage`
*   **Data Processing**: `csv` (for CSV parsing), `file_picker`, `path_provider`, `share_plus`

## Getting Started

### Prerequisites

*   Flutter SDK (^3.10.7 or higher)
*   Dart SDK
*   An emulator or a physical device for testing

### Installation

1.  Clone the repository:
    ```bash
    git clone <repository-url>
    ```
2.  Navigate to the project directory:
    ```bash
    cd financial_tracker_app
    ```
3.  Get Flutter dependencies:
    ```bash
    flutter pub get
    ```
4.  Run the application:
    ```bash
    flutter run
    ```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
