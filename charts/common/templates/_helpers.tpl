{{/*
Short name of the service. Defaults to the chart name (goapi, rscounter, js).
*/}}
{{- define "common.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Resource name. Deliberately NOT release-prefixed: the app relies on stable,
predictable Service DNS (http://goapi:8080, http://rscounter:8081, postgres:5432),
so the Service/Deployment name must equal the service name regardless of release.
*/}}
{{- define "common.fullname" -}}
{{- default .Chart.Name .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels (recommended app.kubernetes.io set).
*/}}
{{- define "common.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "common.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: vc-sampleapp
{{- with .Values.component }}
app.kubernetes.io/component: {{ . }}
{{- end }}
{{- end -}}

{{/*
Selector labels — the immutable subset used by Deployment selectors and Services.
*/}}
{{- define "common.selectorLabels" -}}
app.kubernetes.io/name: {{ include "common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
ServiceAccount name to use.
*/}}
{{- define "common.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "common.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Container image reference. Optional registry prefix (e.g. a JFrog host) + repo,
preferring an immutable digest (stage) over a tag (local).
*/}}
{{- define "common.image" -}}
{{- $repo := .Values.image.repository -}}
{{- with .Values.image.registry -}}
{{- $repo = printf "%s/%s" . $repo -}}
{{- end -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" $repo .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" $repo (.Values.image.tag | default .Chart.AppVersion) -}}
{{- end -}}
{{- end -}}
