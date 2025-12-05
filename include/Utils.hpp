#ifndef UTILS_HPP
#define UTILS_HPP

#include <string>
#include <vector>

// Вспомогательные функции для работы со строками и валидации
// Студенты должны реализовать эти функции по мере необходимости
class Utils {
public:
    // Разбить строку по разделителю
    static std::vector<std::string> split(const std::string& str, char delimiter);
    
    // Удалить пробелы в начале и конце строки
    static std::string trim(const std::string& str);
    
    // Преобразовать в верхний регистр
    static std::string toUpper(const std::string& str);
    
    // Проверить, является ли строка валидным nickname
    static bool isValidNickname(const std::string& nick);
    
    // Проверить, является ли строка валидным именем канала
    static bool isValidChannelName(const std::string& channel);
};

#endif // UTILS_HPP
