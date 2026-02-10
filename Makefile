all : volumes run

volumes:
	@mkdir -p ~/data
	@mkdir -p ~/data/wp ~/data/db
run :
	@cd srcs && \
	if  [ -n "$$(docker image ls 2>/dev/null | sed -n '2 p')" ]; then \
 		docker compose up -d; \
	else \
		docker compose up -d --build; \
	fi
clean :
	@cd srcs && docker compose down -v
fclean : clean
	@docker rmi -f `docker images -q` 2>/dev/null || true
re: fclean all
.PHONY: clean run