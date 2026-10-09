import sys
import unittest
from pathlib import Path

TOOL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL))
from ve1q_harness import *

class VE1QHarnessTests(unittest.TestCase):
    def test_swift_compatible_selected_fields(self):
        p=TOOL/'fixtures/parity/selected-fields.log'
        r=swift_compatible_accumulate(p.read_text().splitlines())
        self.assertEqual(r['bestmove'],'2g2f')
        self.assertEqual([x['multipv'] for x in r['principalVariations']],[1,2,3])
        self.assertEqual(r['principalVariations'][0]['score'],{'type':'cp','value':42,'bound':'lower'})
        self.assertEqual(r['principalVariations'][0]['nps'],2100)
        self.assertEqual(r['principalVariations'][1]['score'],{'type':'mate','value':5,'bound':'upper'})

    def test_swift_compatible_missing_score_can_replace(self):
        p=TOOL/'fixtures/parity/missing-score-swift-compat.log'
        r=swift_compatible_accumulate(p.read_text().splitlines())
        self.assertIsNone(r['principalVariations'][0]['score'])
        with self.assertRaises(ValidationError) as cm:
            strict_validate_raw_log(p)
        self.assertEqual(cm.exception.code,'missing-score')

    def test_strict_rejects_missing_pv(self):
        with self.assertRaises(ValidationError) as cm:
            strict_validate_raw_log(TOOL/'fixtures/known-answer/missing-pv.log')
        self.assertEqual(cm.exception.code,'missing-pv')

    def test_strict_bounds_preserved(self):
        r=strict_validate_raw_log(TOOL/'fixtures/known-answer/lowerbound.log',allow_bounds=True)
        self.assertEqual(r['principalVariations'][0]['score']['bound'],'lower')
        with self.assertRaises(ValidationError):
            strict_validate_raw_log(TOOL/'fixtures/known-answer/lowerbound.log',allow_bounds=False)

    def test_profiles(self):
        p=load_profiles()
        self.assertEqual(p['app-current']['fv_scale'],16)
        self.assertEqual(p['app-candidate']['fv_scale'],24)
        self.assertEqual(p['reference']['fv_scale'],24)
        bad=dict(p['app-current']); bad['fv_scale']=24
        with self.assertRaises(ValidationError): validate_profile_config('app-current',bad)

    def test_in_check_and_guard(self):
        s='k3r4/9/9/9/9/9/9/9/4K4 b - 1'
        self.assertTrue(is_in_check(s))
        self.assertFalse(threat_probe_allowed(s))

    def test_mate1_fixture_is_structurally_legal(self):
        s='8k/9/7R1/9/9/9/9/9/K8 b G 1'
        _,side=parse_sfen(s)
        self.assertEqual(side,'b')
        self.assertFalse(is_in_check(s))

    def test_candidate_validation(self):
        validate_candidate_list(['G*2b'])
        with self.assertRaises(ValidationError): validate_candidate_list(['g*2b'])
        with self.assertRaises(ValidationError): validate_candidate_list([])

    def test_known_fixture_count_and_schema(self):
        d=read_json(TOOL/'fixtures/known-answer/known-answer.json')
        validate_known_fixture(d)
        self.assertGreaterEqual(len(d['cases']),12)

    def test_historical_fixture_demotion(self):
        d=read_json(TOOL/'fixtures/build19-hds-41-49-69.json')
        self.assertEqual(d['authority_status'],'HISTORICAL_DIAGNOSTIC_FIXTURE_ONLY')

if __name__=='__main__': unittest.main()
