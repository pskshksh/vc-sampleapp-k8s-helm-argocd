{{- define "common.configmap" -}}
{{- with .Values.config }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "common.fullname" $ }}
  labels:
    {{- include "common.labels" $ | nindent 4 }}
data:
  {{- range $k, $v := . }}
  {{ $k }}: {{ $v | quote }}
  {{- end }}
{{- end }}
{{- end -}}
