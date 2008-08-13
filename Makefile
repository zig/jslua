
# the lua interpreter used (and inserted into jslua header)
INTERPRETER=	/usr/local/bin/lua-5.1

all: jslua.lua

jslua.lua: jslua.js
	./refjslua.lua jslua.js -o tmpjslua.lua
	$(INTERPRETER) ./tmpjslua.lua jslua.js -o tmpjslua1.lua
	$(INTERPRETER) ./tmpjslua1.lua jslua.js -o tmpjslua2.lua
	@if ! (diff tmpjslua1.lua tmpjslua2.lua > /dev/null) ; then \
		echo "jslua isn't stabilized !" ; false ;\
	else \
		echo "#! $(INTERPRETER)" > jslua.lua ; \
		cat tmpjslua2.lua >> jslua.lua ; \
		chmod +x jslua.lua ; \
		echo "jslua autocompiled succesfully" ; \
	fi

ref: jslua.lua
	mv refjslua.lua refjslua.lua.bak
	cp jslua.lua refjslua.lua
