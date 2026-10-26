import unittest

from prompts import build_prompt, build_smart_prompt


def smart(session_length, hour):
    return build_smart_prompt('rice', None, None, session_length, 'easy', None, 'dinner', hour)


class PromptTests(unittest.TestCase):
    def test_session_lengths_give_the_minutes_the_app_shows(self):
        self.assertIn('at most 30 minutes', build_prompt('rice', session_length='short'))
        self.assertIn('30 to 90 minutes', build_prompt('rice', session_length='long'))
        self.assertIn('at most 30 minutes', build_prompt('rice', session_length='odd'))

    def test_late_night_cap_does_not_override_a_long_session(self):
        self.assertIn('max 15 minutes', smart('short', 21))
        self.assertNotIn('max 15 minutes', smart('long', 21))
        self.assertIn('30 to 90 minutes', smart('long', 21))


if __name__ == '__main__':
    unittest.main()
