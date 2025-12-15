#!/bin/bash
set -e

# Run any extra initialization *after* IRIS is already running
iris session IRIS <<'EOF'
write "PRINT THIS: SEE MEEE HERE"
s version="latest" s r=##class(%Net.HttpRequest).%New(),r.Server="pm.community.intersystems.com",r.SSLConfiguration="ISC.FeatureTracker.SSL.Config" d r.Get("/packages/zpm/"_version_"/installer"),$system.OBJ.LoadStream(r.HttpResponse.Data,"c")
q
halt
EOF
