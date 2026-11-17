// SPDX-License-Identifier: GPL-3.0-only
// Part of Zonari (Copyright (c) 2026 lhenr1que).
// src/bars/hostDrag.hpp is not included by any plugin source while the title-bar drag is off (alpha-0), so the build no
// longer checks it: tests/test-plugin-hostdrag.sh compiles this file (syntax only) against the installed headers.
#include "hostDrag.hpp"

#include <type_traits>

static_assert(std::is_same_v<decltype(&KwDrag::begin), KwDrag::eBeginResult (*)(eMouseBindMode)>);
