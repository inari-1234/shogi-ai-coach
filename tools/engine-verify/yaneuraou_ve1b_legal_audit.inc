#include <deque>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

#include "movegen.h"

namespace {

std::string ve1b_move_to_usi(YaneuraOu::Move move) {
    std::ostringstream out;
    if (move.is_drop()) {
        out << move.move_dropped_piece() << '*' << move.to_sq();
    } else {
        out << move.from_sq() << move.to_sq();
        if (move.is_promote())
            out << '+';
    }
    return out.str();
}

bool ve1b_parse_usi_candidate(
    const YaneuraOu::Position& pos,
    const std::string& token,
    YaneuraOu::Move& result
) {
    using namespace YaneuraOu;

    if (token.size() == 4 && token[1] == '*') {
        PieceType pt;
        switch (token[0]) {
        case 'P': pt = PAWN; break;
        case 'L': pt = LANCE; break;
        case 'N': pt = KNIGHT; break;
        case 'S': pt = SILVER; break;
        case 'G': pt = GOLD; break;
        case 'B': pt = BISHOP; break;
        case 'R': pt = ROOK; break;
        default: return false;
        }
        const Square to = make_square(toFile(token[2]), toRank(token[3]));
        result = make_move_drop(pt, to, pos.side_to_move());
        return true;
    }

    if (token.size() != 4 && token.size() != 5)
        return false;
    if (token.size() == 5 && token[4] != '+')
        return false;

    const Square from = make_square(toFile(token[0]), toRank(token[1]));
    const Square to = make_square(toFile(token[2]), toRank(token[3]));
    const Piece pc = pos.piece_on(from);
    if (pc == NO_PIECE)
        return false;

    result = token.size() == 5
        ? make_move_promote(from, to, pc)
        : make_move(from, to, pc);
    return true;
}

bool ve1b_find_legal_all_move(
    const YaneuraOu::Position& pos,
    const std::string& token,
    YaneuraOu::Move& result
) {
    using namespace YaneuraOu;
    Move candidate;
    if (!ve1b_parse_usi_candidate(pos, token, candidate))
        return false;

    for (Move move : MoveList<LEGAL_ALL>(pos)) {
        if (move == candidate) {
            result = move;
            return true;
        }
    }
    return false;
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
        try {
            ply = std::stoi(line.substr(0, tab));
        } catch (...) {
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
