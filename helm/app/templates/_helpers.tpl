{{- define "demo-app.name" -}}demo-app{{- end }}
{{- define "demo-app.fullname" -}}{{ include "demo-app.name" . }}{{- end }}
{{- define "demo-app.serviceAccountName" -}}{{ default (include "demo-app.fullname" .) .Values.serviceAccount.name }}{{- end }}
