import json
from flask import Response, Flask, render_template, request
import hashlib
from rq import Queue, Worker
from rq.job import Job
import os
import redis
import drill
from rq.registry import FinishedJobRegistry
import auto_scale

app = Flask(__name__)

RESULT_TTL = 1000  # SECONDS

redis_url = os.getenv('REDIS_HOST')
conn = redis.from_url(redis_url)
q = Queue(connection=conn, serializer=drill, result_ttl=RESULT_TTL)

instances_list = []
# create first worker
auto_scale.upscale(instances_list)


@app.route('/', methods=['GET'])
def index():
    return render_template('index.html')


@app.route('/enqueue', methods=['GET', 'PUT'])
def send_task():
    if request.method == "PUT":
        iterations = request.args.get("iterations")
        body = request.data
        job = q.enqueue_call(
            func=work, args=(body, iterations,), result_ttl=5000)
        print(job.get_id())
        print(len(q))
        print(q.jobs)
        workers = Worker.all(connection=conn)
        print(workers)
        auto_scale.scale(q, instances_list)
        return Response(mimetype='application/json',
                        response=json.dumps(job.get_id()), status=200)


@app.route('/pullCompleted', methods=['GET', 'POST'])
def results():
    if request.method == "POST":
        top = request.args.get("top")

        completed_list = FinishedJobRegistry(name='default', connection=conn).get_job_ids()
        completed_list = completed_list[-int(top):]
        resultsList = []
        for job_key in completed_list:
            job = Job.fetch(job_key, connection=conn)
            dict = {"job id": job_key, "result": str(job.result)}
            resultsList.append(dict)
        return Response(mimetype='application/json',
                        response=json.dumps(resultsList), status=200)


def work(buffer, iterations):
    iterations = int(iterations)
    output = hashlib.sha512(buffer).digest()
    for i in range(iterations - 1):
        output = hashlib.sha512(output).digest()
    return output


app.run()
