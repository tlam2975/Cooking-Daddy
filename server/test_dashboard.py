import unittest

from dashboard_service import DashboardService, normalize_language


class DashboardBriefTests(unittest.TestCase):
    def test_same_day_pairs_tip_and_image_across_languages(self):
        service = DashboardService()
        en = service.get_daily_brief('2026-10-14', 'en')
        vi = service.get_daily_brief('2026-10-14', 'vi')
        self.assertEqual(en['imageUrl'], vi['imageUrl'])
        self.assertEqual(vi['lang'], 'vi')
        self.assertNotEqual(en['tip'], vi['tip'])
        self.assertEqual(vi['title'], 'Ghi chú bếp hôm nay')

    def test_unknown_language_falls_back_to_english(self):
        self.assertEqual(normalize_language('fr'), 'en')
        self.assertEqual(normalize_language(None), 'en')
        self.assertEqual(normalize_language('vi-VN'), 'vi')
        brief = DashboardService().get_daily_brief('2026-10-14', 'xx')
        self.assertEqual(brief['title'], 'Daily kitchen note')

    def test_cache_is_keyed_by_day_and_language(self):
        service = DashboardService()
        first = service.get_daily_brief('2026-10-14', 'en')
        self.assertIs(first, service.get_daily_brief('2026-10-14', 'en'))
        self.assertIsNot(first, service.get_daily_brief('2026-10-14', 'vi'))


if __name__ == '__main__':
    unittest.main()
