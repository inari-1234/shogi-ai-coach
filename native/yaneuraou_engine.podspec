Pod::Spec.new do |s|
  s.name = 'yaneuraou_engine'
  s.version = '0.1.0'
  s.summary = 'YaneuraOu V9.00 NNUE engine bridge for Shogi AI Coach'
  s.homepage = 'https://github.com/inari-1234/shogi-ai-coach'
  s.license = { :type => 'GPL-3.0-or-later' }
  s.author = { 'Shogi AI Coach' => 'noreply@example.invalid' }
  s.source = { :path => '.' }
  s.platform = :ios, '16.0'
  s.requires_arc = false

  yo = 'third_party/YaneuraOu/source'
  s.source_files = [
    'bridge/engine_bridge.cpp', 'bridge/engine_bridge.h',
    "#{yo}/types.cpp", "#{yo}/bitboard.cpp", "#{yo}/misc.cpp", "#{yo}/memory.cpp",
    "#{yo}/movegen.cpp", "#{yo}/position.cpp", "#{yo}/usi.cpp", "#{yo}/usioption.cpp",
    "#{yo}/thread.cpp", "#{yo}/tt.cpp", "#{yo}/movepick.cpp", "#{yo}/timeman.cpp",
    "#{yo}/engine.cpp", "#{yo}/search.cpp", "#{yo}/score.cpp", "#{yo}/benchmark.cpp",
    "#{yo}/tune.cpp", "#{yo}/book/book.cpp", "#{yo}/book/apery_book.cpp",
    "#{yo}/book/policybook.cpp", "#{yo}/book/makebook.cpp", "#{yo}/book/makebook2015.cpp",
    "#{yo}/book/makebook2025.cpp", "#{yo}/learn/learner.cpp", "#{yo}/learn/learning_tools.cpp",
    "#{yo}/learn/multi_think.cpp", "#{yo}/extra/bitop.cpp", "#{yo}/extra/long_effect.cpp",
    "#{yo}/extra/sfen_packer.cpp", "#{yo}/mate/mate.cpp", "#{yo}/mate/mate1ply_without_effect.cpp",
    "#{yo}/mate/mate1ply_with_effect.cpp", "#{yo}/mate/mate_solver.cpp",
    "#{yo}/eval/evaluate_bona_piece.cpp", "#{yo}/eval/evaluate.cpp", "#{yo}/eval/evaluate_io.cpp",
    "#{yo}/eval/evaluate_mir_inv_tools.cpp", "#{yo}/eval/material/evaluate_material.cpp",
    "#{yo}/testcmd/unit_test.cpp", "#{yo}/testcmd/mate_test_cmd.cpp", "#{yo}/testcmd/normal_test_cmd.cpp",
    "#{yo}/engine/yaneuraou-engine/yaneuraou-search.cpp",
    "#{yo}/eval/nnue/evaluate_nnue.cpp", "#{yo}/eval/nnue/evaluate_nnue_learner.cpp",
    "#{yo}/eval/nnue/nnue_test_command.cpp", "#{yo}/eval/nnue/features/k.cpp",
    "#{yo}/eval/nnue/features/p.cpp", "#{yo}/eval/nnue/features/half_kp.cpp",
    "#{yo}/eval/nnue/features/half_kp_vm.cpp", "#{yo}/eval/nnue/features/half_relative_kp.cpp",
    "#{yo}/eval/nnue/features/half_kpe9.cpp", "#{yo}/eval/nnue/features/pe9.cpp"
  ]
  s.public_header_files = 'bridge/engine_bridge.h'
  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/third_party/YaneuraOu/source" "$(PODS_TARGET_SRCROOT)/bridge"',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'GCC_PREPROCESSOR_DEFINITIONS' => 'NDEBUG=1 _LINUX=1 UNICODE=1 NO_EXCEPTIONS=1 IS_64BIT=1 YANEURAOU_ENGINE_NNUE=1 EVAL_NNUE_HALFKP256=1',
    'OTHER_CPLUSPLUSFLAGS' => '-O2 -fno-exceptions -fno-rtti -fpermissive -w',
    'DEAD_CODE_STRIPPING' => 'NO'
  }
end
