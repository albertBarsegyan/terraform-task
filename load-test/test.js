import http from 'k6/http';
import { check, sleep } from 'k6';

const baseUrl = __ENV.BASE_URL;
if (!baseUrl) throw new Error('Set BASE_URL, e.g. https://demo.example.com');
export const options = {
  stages: [
    { duration: '30s', target: 10 }, { duration: '30s', target: 25 },
    { duration: '30s', target: 50 }, { duration: '30s', target: 100 },
    { duration: '30s', target: 0 }
  ],
  thresholds: { http_req_failed: ['rate<0.01'], http_req_duration: ['p(95)<1000'] }
};
export default function () {
  const response = http.get(`${baseUrl}/health`);
  check(response, { 'health returns 200': (r) => r.status === 200 });
  sleep(1);
}
