PROJECT_ROOT := $(shell pwd)

.PHONY: nginx monitor cleanup env destroy logs outages stop-monitors clean status

nginx:
	docker rm -f sandbox-nginx 2>/dev/null || true
	docker run -d \
		--name sandbox-nginx \
		--network sandbox-shared-net \
		-p 80:80 \
		-v "$(PROJECT_ROOT)/nginx/nginx.conf:/etc/nginx/nginx.conf:ro" \
		-v "$(PROJECT_ROOT)/nginx/conf.d:/etc/nginx/conf.d" \
		nginx:latest

monitor:
	pkill -f health_monitor.sh || true
	nohup ./monitor/health_monitor.sh > /dev/null 2>&1 &

cleanup:
	pkill -f cleanup_daemon.sh || true
	nohup ./platform/cleanup_daemon.sh > /dev/null 2>&1 &

env:
ifndef NAME
	$(error NAME is required. Usage: make env NAME=test TTL=300)
endif
	./platform/create_env.sh $(NAME) $(TTL)

destroy:
ifndef ENV
	$(error ENV is required. Usage: make destroy ENV=env-xxxxxx)
endif
	./platform/destroy_env.sh $(ENV)

logs:
	tail -f logs/monitor.log

outages:
	tail -f logs/outages.log

status:
	docker ps
	echo ""
	docker network ls
	echo ""
	ls envs

stop-monitors:
	pkill -f health_monitor.sh || true
	pkill -f cleanup_daemon.sh || true

clean:
	rm -f nginx/conf.d/*.conf || true
	rm -f envs/*.json || true
	docker rm -f sandbox-nginx 2>/dev/null || true
	docker rm -f $$(docker ps -aq --filter "name=sandbox-env-") 2>/dev/null || true

outage:
	./platform/simulate_outage.sh $(ENV) $(MODE)

recover:
	./platform/simulate_outage.sh $(ENV) recover