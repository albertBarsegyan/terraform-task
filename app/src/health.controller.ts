import { Controller, Get, Req, Res } from '@nestjs/common';
import type { Request, Response } from 'express';
import { collectDefaultMetrics, Counter, Histogram, Registry } from 'prom-client';

const registry = new Registry();
collectDefaultMetrics({ register: registry, prefix: 'app_' });
const requests = new Counter({
  name: 'app_http_requests_total',
  help: 'HTTP requests',
  labelNames: ['method', 'route', 'status_code'] as const,
  registers: [registry],
});
const duration = new Histogram({
  name: 'app_http_request_duration_seconds',
  help: 'HTTP request duration',
  labelNames: ['method', 'route', 'status_code'] as const,
  registers: [registry],
});

@Controller()
export class HealthController {
  private respond(req: Request, res: Response, route: string, body: object) {
    const end = duration.startTimer({ method: req.method, route });
    requests.inc({ method: req.method, route, status_code: '200' });
    end({ status_code: '200' });
    console.log(
      JSON.stringify({
        level: 'info',
        event: 'http_request',
        method: req.method,
        route,
        statusCode: 200,
        timestamp: new Date().toISOString(),
      }),
    );

    return res.status(200).json(body);
  }

  @Get()
  root(@Req() req: Request, @Res() res: Response) {
    return this.respond(req, res, '/', { message: 'EKS platform demo' });
  }

  @Get('health')
  health(@Req() req: Request, @Res() res: Response) {
    return this.respond(req, res, '/health', { status: 'ok' });
  }

  @Get('api/items')
  items(@Req() req: Request, @Res() res: Response) {
    return this.respond(req, res, '/api/items', {
      items: [{ id: 1, name: 'example' }],
    });
  }

  @Get('metrics')
  async metrics(@Res() res: Response) {
    res.setHeader('Content-Type', registry.contentType);
    return res.send(await registry.metrics());
  }
}
