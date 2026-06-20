# Makefile for Mochi apps
# Copyright © 2026 Mochi OÜ
# SPDX-License-Identifier: AGPL-3.0-only
# This file is part of Mochi, licensed under the GNU AGPL v3 with the
# Mochi Application Interface Exception - see license.txt and license-exception.md.

all: web/dist/index.html

clean:
	rm -rf web/dist

web/dist/index.html: $(shell find web/src -type f -newer web/dist/index.html -print 2>/dev/null || true)
	cd web && pnpm run build
