#!/bin/bash
set -e

iris session IRIS <<'EOF'

/* Install IPM/ZPM client if you still need that first
   (your original snippet did this already) */
s version="latest" s r=##class(%Net.HttpRequest).%New(),r.Server="pm.community.intersystems.com",r.SSLConfiguration="ISC.FeatureTracker.SSL.Config" d r.Get("/packages/zpm/"_version_"/installer"),$system.OBJ.LoadStream(r.HttpResponse.Data,"c")

/* Configure registry */
zpm
repo -r -n registry -url https://pm.community.intersystems.com/ -user "" -pass ""
install csvgenpy
quit

/* Upload csv data ONCE to Table Automatically using csvgenpy */
SET exists = ##class(%SYSTEM.SQL.Schema).TableExists("MockPackage.NoShowsAppointments")
IF 'exists {   do ##class(shvarov.csvgenpy.csv).Generate("/dur/data/healthcare_noshows_appointments.csv","NoShowsAppointments","MockPackage")   }

halt
EOF
