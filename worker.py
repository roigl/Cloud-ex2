import os
import redis
from rq import Worker, Queue, Connection
import hashlib

listen = ['default']
redis_url = os.getenv('REDIS_HOST')
conn = redis.from_url(redis_url)

def work(buffer, iterations):
    iterations = int(iterations)
    output = hashlib.sha512(buffer).digest()
    for i in range(iterations - 1):
        output = hashlib.sha512(output).digest()
    return output

if __name__ == "__main__":
    with Connection(conn):
        worker = Worker(list(map(Queue, listen)))
        worker.work()
