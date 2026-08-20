{{/*
common.pdb — PodDisruptionBudget. Only meaningful at 2+ replicas; keep disabled
for single-replica local. Set minAvailable OR maxUnavailable, not both.
*/}}
{{- define "common.pdb" -}}
{{- if .Values.pdb.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "common.fullname" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  {{- if .Values.pdb.minAvailable }}
  minAvailable: {{ .Values.pdb.minAvailable }}
  {{- else }}
  maxUnavailable: {{ .Values.pdb.maxUnavailable | default 1 }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "common.selectorLabels" . | nindent 6 }}
{{- end }}
{{- end -}}
