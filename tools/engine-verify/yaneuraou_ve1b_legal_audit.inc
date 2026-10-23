#include <deque>
#include <fstream>
#include <limits>
#include <sstream>
#include <string>
#include <vector>

#include "movegen.h"
#include "usi.h"

namespace {

std::string ve1b_move_to_usi(YaneuraOu::Move move) {
    return YaneuraOu::USIEngine::move(move);
}

bool ve1b_find_legal_all_move(
    const YaneuraOu::Position& pos,
    const std::string& token,
    YaneuraOu::Move& result
) {
    using namespace YaneuraOu;

    // Replay strictly against the engine's LEGAL_ALL universe so historical
    // game moves that search-root LEGAL may omit remain reconstructible.
    for (Move move : MoveList<LEGAL_ALL>(pos)) {
        if (USIEngine::move(move) == token) {
            result = move;
            return true;
        }
    }
    return false;
}

bool ve1b_parse_nonnegative_int(const std::string& text, int& result) {
    if (text.empty())
        return false;

    int value = 0;
    for (char c : text) {
        if (c < '0' || c > '9')
            return false;
        const int digit = c - '0';
        if (value > (std::numeric_limits<int>::max() - digit) / 10)
            return false;
        value = value * 10 + digit;
    }
    result = value;
    return true;
}

bool ve1b_build_position(
    const std::string& command,
    YaneuraOu::Position& pos,
    std::deque<YaneuraOu::StateInfo>& states,
    std::string& error
) {
    using namespace YaneuraOu;

    std::istringstream input(command);
    std::string token;
    if (!(input >> token) || token != "position") {
        error = "missing position prefix";
        return false;
    }

    if (!(input >> token)) {
        error = "missing position body";
        return false;
    }

    std::string sfen;
    if (token == "startpos") {
        sfen = StartSFEN;
        if (input >> token) {
            if (token != "moves") {
                error = "unexpected token after startpos: " + token;
                return false;
            }
        } else {
            token.clear();
        }
    } else if (token == "sfen") {
        std::string board, side, hand, ply;
        if (!(input >> board >> side >> hand >> ply)) {
            error = "incomplete sfen";
            return false;
        }
        sfen = board + " " + side + " " + hand + " " + ply;
        if (input >> token) {
            if (token != "moves") {
                error = "unexpected token after sfen: " + token;
                return false;
            }
        } else {
            token.clear();
        }
    } else {
        error = "unsupported position body: " + token;
        return false;
    }

    states.clear();
    states.emplace_back();
    pos.set(sfen, &states.back());

    if (token.empty())
        return true;

    std::string moveToken;
    while (input >> moveToken) {
        Move move;
        if (!ve1b_find_legal_all_move(pos, moveToken, move)) {
            error = "move is not in MoveList<LEGAL_ALL>: " + moveToken;
            return false;
        }
        states.emplace_back();
        pos.do_move(move, states.back());
    }
    return true;
}

int ve1b_run_legal_audit(const std::string& inputPath) {
    using namespace YaneuraOu;

    std::ifstream input(inputPath);
    if (!input) {
        std::cerr << "VE1B_ERROR\tinput_open_failed\t" << inputPath << std::endl;
        return 70;
    }

    std::string line;
    int row = 0;
    while (std::getline(input, line)) {
        ++row;
        if (line.empty())
            continue;

        const auto tab = line.find('\t');
        if (tab == std::string::npos) {
            std::cerr << "VE1B_ERROR\tbad_input_row\t" << row << std::endl;
            return 71;
        }

        int ply;
        if (!ve1b_parse_nonnegative_int(line.substr(0, tab), ply)) {
            std::cerr << "VE1B_ERROR\tbad_ply\t" << row << std::endl;
            return 72;
        }
        const std::string command = line.substr(tab + 1);

        Position pos;
        std::deque<StateInfo> states;
        std::string error;
        if (!ve1b_build_position(command, pos, states, error)) {
            std::cerr << "VE1B_ERROR\tposition_build\t" << ply << '\t' << error << std::endl;
            return 73;
        }

        std::vector<std::string> legalAll;
        for (Move move : MoveList<LEGAL_ALL>(pos))
            legalAll.emplace_back(ve1b_move_to_usi(move));
        const size_t legalCount = MoveList<LEGAL>(pos).size();

        std::cout << "VE1B\t" << ply << '\t' << legalCount << '\t' << legalAll.size() << '\t';
        for (size_t i = 0; i < legalAll.size(); ++i) {
            if (i)
                std::cout << ' ';
            std::cout << legalAll[i];
        }
        std::cout << std::endl;
    }

    return 0;
}

} // namespace
