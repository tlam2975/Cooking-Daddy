from threading import Lock
from quota_service import QuotaExceeded

class MemoryQuota:
    def __init__(self):
        self.counts = {}
        self.lock = Lock()
    def snapshot(self, uid, limit):
        with self.lock:
            return {'remaining': max(0, limit - self.counts.get(uid, 0)), 'limit': limit}
    def reserve(self, uid, limit):
        with self.lock:
            count = self.counts.get(uid, 0)
            if count >= limit:
                raise QuotaExceeded
            self.counts[uid] = count + 1
            return 'reservation', limit - count - 1
    def release(self, uid, reservation):
        with self.lock:
            self.counts[uid] = max(0, self.counts.get(uid, 0) - 1)
