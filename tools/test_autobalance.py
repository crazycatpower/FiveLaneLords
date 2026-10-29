"""Metric aggregation regressions; no simulation or balance writes."""
import unittest
import autobalance as a


class CardDetailsTest(unittest.TestCase):
    cards = {"militia": ("民兵隊", 8), "guard": ("聖堂護衛", 30)}

    def test_weighted_damage_and_played_only_first_time(self):
        results = [
            {"card_stats": [{"militia": {"plays": 1, "first_play": 10, "spent": 8, "damage": 80}},
                            {"militia": {"plays": 0, "first_play": None, "spent": 0, "damage": 0}}]},
            {"card_stats": [{"militia": {"plays": 3, "first_play": 30, "spent": 24, "damage": 480}}]},
        ]
        d = a.card_details(results, self.cards)["militia"]
        self.assertEqual(d["samples"], 3)  # both mirror sides count
        self.assertAlmostEqual(d["plays_per_match"], 4 / 3)
        self.assertEqual(d["first_play"], 20)
        self.assertEqual(d["damage_per_gold"], 560 / 32)

    def test_unattributable_legion_is_not_zero_damage(self):
        rows = [{"card_stats": [{"guard": {"plays": 2, "first_play": 50, "spent": 60, "damage": None}}]}]
        d = a.card_details(rows, self.cards)["guard"]
        self.assertIsNone(d["damage_per_gold"])
        self.assertEqual(d["plays_per_match"], 2)

    def test_legacy_and_no_spend_stay_unavailable(self):
        self.assertIsNone(a.card_details([{}], self.cards)["militia"]["damage_per_gold"])
        rows = [{"card_stats": [{"militia": {"plays": 0, "first_play": None, "spent": 0, "damage": 10}}]}]
        self.assertIsNone(a.card_details(rows, self.cards)["militia"]["damage_per_gold"])

    def test_report_columns_exist_even_for_legacy_results(self):
        r = {"winner": 0, "t": 100, "decks": [["militia"], ["guard"]], "lords": ["lion", "iron"]}
        report = a.table(a.analyse([r], self.cards), self.cards, {})
        for column in ["平均出牌次數", "每金幣傷害", "平均第一次出牌時間"]:
            self.assertIn(column, report)
        self.assertIn("—", report)
        self.assertIn("軍團", report)


if __name__ == "__main__":
    unittest.main()
