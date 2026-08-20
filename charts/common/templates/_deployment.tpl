{{/*
common.deployment — a hardened Deployment shared by js, goapi and rscounter.
*/}}
{{- define "common.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "common.fullname" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "common.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        {{- with .Values.config }}
        checksum/config: {{ toYaml . | sha256sum }}
        {{- end }}
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "common.selectorLabels" . | nindent 8 }}
    spec:
      serviceAccountName: {{ include "common.serviceAccountName" . }}
      automountServiceAccountToken: {{ .Values.serviceAccount.automount }}
      terminationGracePeriodSeconds: {{ .Values.terminationGracePeriodSeconds | default 30 }}
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          image: {{ include "common.image" . }}
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          ports:
            - name: http
              containerPort: {{ .Values.service.targetPort }}
              protocol: TCP
          {{- with .Values.config }}
          envFrom:
            - configMapRef:
                name: {{ include "common.fullname" $ }}
          {{- end }}
          {{- with .Values.secretEnv }}
          env:
            {{- range . }}
            - name: {{ .name }}
              valueFrom:
                secretKeyRef:
                  name: {{ .secretName }}        # pre-existing Secret — the chart never sees the value
                  key: {{ .secretKey }}
            {{- end }}
          {{- end }}
          {{- with .Values.probes.liveness }}
          livenessProbe:
            httpGet:
              path: {{ .path }}
              port: {{ .port }}
            periodSeconds: {{ .periodSeconds | default 10 }}
            failureThreshold: {{ .failureThreshold | default 3 }}
          {{- end }}
          {{- with .Values.probes.readiness }}
          readinessProbe:
            httpGet:
              path: {{ .path }}
              port: {{ .port }}
            periodSeconds: {{ .periodSeconds | default 5 }}
            failureThreshold: {{ .failureThreshold | default 3 }}
          {{- end }}
          {{- if .Values.probes.startup.enabled }}
          startupProbe:
            httpGet:
              path: {{ .Values.probes.startup.path }}
              port: {{ .Values.probes.startup.port }}
            periodSeconds: {{ .Values.probes.startup.periodSeconds | default 2 }}
            failureThreshold: {{ .Values.probes.startup.failureThreshold | default 30 }}
          {{- end }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          {{- with .Values.volumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}
      {{- with .Values.volumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.topologySpreadConstraints }}
      topologySpreadConstraints:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end -}}
