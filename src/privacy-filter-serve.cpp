#include "pf.h"

#include <cstddef>
#include <cstdlib>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

namespace {

struct Request
{
    std::string id;
    std::string text;
    float threshold = 0.5F;
};

class JsonParser
{
public:
    explicit JsonParser(const std::string & json) : json(json) {}

    bool parse(Request & request, std::string & error)
    {
        skipWhitespace();

        if (! consume('{')) {
            error = "Expected JSON object.";
            return false;
        }

        skipWhitespace();

        if (consume('}')) {
            error = "Request object cannot be empty.";
            return false;
        }

        while (true) {
            std::string key;

            if (! parseString(key, error)) {
                return false;
            }

            skipWhitespace();

            if (! consume(':')) {
                error = "Expected ':' after object key.";
                return false;
            }

            skipWhitespace();

            if (key == "id") {
                if (! parseString(request.id, error)) {
                    return false;
                }
            } else if (key == "text") {
                if (! parseString(request.text, error)) {
                    return false;
                }
            } else if (key == "threshold") {
                double value = 0.0;

                if (! parseNumber(value, error)) {
                    return false;
                }

                request.threshold = static_cast<float>(value);
            } else {
                if (! skipValue(error)) {
                    return false;
                }
            }

            skipWhitespace();

            if (consume('}')) {
                break;
            }

            if (! consume(',')) {
                error = "Expected ',' or '}' after object value.";
                return false;
            }

            skipWhitespace();
        }

        skipWhitespace();

        if (position != json.size()) {
            error = "Unexpected trailing JSON content.";
            return false;
        }

        if (request.text.empty()) {
            error = "Request text is required.";
            return false;
        }

        return true;
    }

private:
    const std::string & json;
    std::size_t position = 0;

    void skipWhitespace()
    {
        while (position < json.size() && std::strchr(" \t\r\n", json[position]) != nullptr) {
            position++;
        }
    }

    bool consume(char character)
    {
        if (position < json.size() && json[position] == character) {
            position++;

            return true;
        }

        return false;
    }

    bool parseString(std::string & value, std::string & error)
    {
        if (! consume('"')) {
            error = "Expected JSON string.";
            return false;
        }

        value.clear();

        while (position < json.size()) {
            char character = json[position++];

            if (character == '"') {
                return true;
            }

            if (character != '\\') {
                value += character;
                continue;
            }

            if (position >= json.size()) {
                error = "Unterminated JSON escape sequence.";
                return false;
            }

            character = json[position++];

            switch (character) {
                case '"':
                case '\\':
                case '/':
                    value += character;
                    break;
                case 'b':
                    value += '\b';
                    break;
                case 'f':
                    value += '\f';
                    break;
                case 'n':
                    value += '\n';
                    break;
                case 'r':
                    value += '\r';
                    break;
                case 't':
                    value += '\t';
                    break;
                case 'u':
                    if (! parseUnicodeEscape(value, error)) {
                        return false;
                    }
                    break;
                default:
                    error = "Unsupported JSON escape sequence.";
                    return false;
            }
        }

        error = "Unterminated JSON string.";

        return false;
    }

    bool parseUnicodeEscape(std::string & value, std::string & error)
    {
        uint32_t codepoint = 0;

        if (! parseHexCodepoint(codepoint)) {
            error = "Invalid JSON unicode escape sequence.";
            return false;
        }

        if (codepoint >= 0xD800 && codepoint <= 0xDBFF) {
            if (position + 2 > json.size() || json[position] != '\\' || json[position + 1] != 'u') {
                error = "Invalid JSON unicode surrogate pair.";
                return false;
            }

            position += 2;

            uint32_t lowSurrogate = 0;

            if (! parseHexCodepoint(lowSurrogate) || lowSurrogate < 0xDC00 || lowSurrogate > 0xDFFF) {
                error = "Invalid JSON unicode surrogate pair.";
                return false;
            }

            codepoint = 0x10000 + ((codepoint - 0xD800) << 10) + (lowSurrogate - 0xDC00);
        }

        appendUtf8(value, codepoint);

        return true;
    }

    bool parseHexCodepoint(uint32_t & codepoint)
    {
        if (position + 4 > json.size()) {
            return false;
        }

        codepoint = 0;

        for (int index = 0; index < 4; index++) {
            const char character = json[position++];
            uint32_t value = 0;

            if (character >= '0' && character <= '9') {
                value = static_cast<uint32_t>(character - '0');
            } else if (character >= 'a' && character <= 'f') {
                value = static_cast<uint32_t>(character - 'a' + 10);
            } else if (character >= 'A' && character <= 'F') {
                value = static_cast<uint32_t>(character - 'A' + 10);
            } else {
                return false;
            }

            codepoint = (codepoint << 4) | value;
        }

        return true;
    }

    static void appendUtf8(std::string & value, uint32_t codepoint)
    {
        if (codepoint <= 0x7F) {
            value += static_cast<char>(codepoint);
        } else if (codepoint <= 0x7FF) {
            value += static_cast<char>(0xC0 | (codepoint >> 6));
            value += static_cast<char>(0x80 | (codepoint & 0x3F));
        } else if (codepoint <= 0xFFFF) {
            value += static_cast<char>(0xE0 | (codepoint >> 12));
            value += static_cast<char>(0x80 | ((codepoint >> 6) & 0x3F));
            value += static_cast<char>(0x80 | (codepoint & 0x3F));
        } else {
            value += static_cast<char>(0xF0 | (codepoint >> 18));
            value += static_cast<char>(0x80 | ((codepoint >> 12) & 0x3F));
            value += static_cast<char>(0x80 | ((codepoint >> 6) & 0x3F));
            value += static_cast<char>(0x80 | (codepoint & 0x3F));
        }
    }

    bool parseNumber(double & value, std::string & error)
    {
        const char * start = json.c_str() + position;
        char * end = nullptr;

        value = std::strtod(start, &end);

        if (end == start) {
            error = "Expected JSON number.";
            return false;
        }

        position = static_cast<std::size_t>(end - json.c_str());

        return true;
    }

    bool skipValue(std::string & error)
    {
        if (position >= json.size()) {
            error = "Expected JSON value.";
            return false;
        }

        if (json[position] == '"') {
            std::string ignored;

            return parseString(ignored, error);
        }

        if (json[position] == '-' || (json[position] >= '0' && json[position] <= '9')) {
            double ignored = 0.0;

            return parseNumber(ignored, error);
        }

        if (json.compare(position, 4, "true") == 0) {
            position += 4;

            return true;
        }

        if (json.compare(position, 5, "false") == 0) {
            position += 5;

            return true;
        }

        if (json.compare(position, 4, "null") == 0) {
            position += 4;

            return true;
        }

        error = "Unsupported JSON value.";

        return false;
    }
};

std::string escapeJson(const std::string & value)
{
    std::ostringstream escaped;

    for (const char character : value) {
        switch (character) {
            case '"':
                escaped << "\\\"";
                break;
            case '\\':
                escaped << "\\\\";
                break;
            case '\b':
                escaped << "\\b";
                break;
            case '\f':
                escaped << "\\f";
                break;
            case '\n':
                escaped << "\\n";
                break;
            case '\r':
                escaped << "\\r";
                break;
            case '\t':
                escaped << "\\t";
                break;
            default:
                escaped << character;
        }
    }

    return escaped.str();
}

std::string entityText(const std::string & text, const pf_entity & entity)
{
    if (entity.start < 0 || entity.end < entity.start) {
        return "";
    }

    const auto start = static_cast<std::size_t>(entity.start);
    const auto end = static_cast<std::size_t>(entity.end);

    if (start > text.size() || end > text.size()) {
        return "";
    }

    return text.substr(start, end - start);
}

void writeError(const std::string & id, const std::string & error)
{
    std::cout << "{\"id\":\"" << escapeJson(id) << "\",\"error\":\"" << escapeJson(error) << "\"}" << std::endl;
}

void writeResponse(const Request & request, const pf_entity * entities, std::size_t count)
{
    std::cout << "{\"id\":\"" << escapeJson(request.id) << "\",\"entities\":[";

    for (std::size_t index = 0; index < count; index++) {
        const pf_entity & entity = entities[index];

        if (index > 0) {
            std::cout << ',';
        }

        std::cout
            << "{\"type\":\"" << escapeJson(entity.label == nullptr ? "" : entity.label) << "\","
            << "\"text\":\"" << escapeJson(entityText(request.text, entity)) << "\","
            << "\"start\":" << entity.start << ','
            << "\"end\":" << entity.end << ','
            << "\"score\":" << std::setprecision(8) << entity.score
            << '}';
    }

    std::cout << "]}" << std::endl;
}

void usage()
{
    std::cerr << "usage: privacy-filter-serve <model.gguf> [threshold]" << std::endl;
}

} // namespace

int main(int argc, char ** argv)
{
    if (argc < 2 || argc > 3) {
        usage();

        return 2;
    }

    float defaultThreshold = 0.5F;

    if (argc == 3) {
        defaultThreshold = static_cast<float>(std::strtod(argv[2], nullptr));
    }

    pf_ctx * context = pf_load(argv[1], "cpu", 0);

    if (context == nullptr) {
        std::cerr << "failed to load model" << std::endl;

        return 1;
    }

    std::string line;

    while (std::getline(std::cin, line)) {
        Request request;
        request.threshold = defaultThreshold;

        std::string error;

        if (! JsonParser(line).parse(request, error)) {
            writeError(request.id, error);
            continue;
        }

        pf_entity * entities = nullptr;
        std::size_t count = 0;

        const int result = pf_classify(
            context,
            request.text.data(),
            request.text.size(),
            request.threshold,
            &entities,
            &count
        );

        if (result != 0) {
            writeError(request.id, pf_last_error(context) == nullptr ? "Classification failed." : pf_last_error(context));
            pf_entities_free(entities, count);
            continue;
        }

        writeResponse(request, entities, count);

        pf_entities_free(entities, count);
    }

    pf_free(context);

    return 0;
}
