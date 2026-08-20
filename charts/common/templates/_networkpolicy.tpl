{{/*
common.networkpolicy — per-service default-deny. Because a policy selects this
pod, all ingress not explicitly allowed is denied. Egress allows DNS plus the
explicit downstream hop(s): js -> goapi -> rscounter -> postgres.
*/}}
{{- define "common.networkpolicy" -}}
{{- if .Values.networkPolicy.enabled }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "common.fullname" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      {{- include "common.selectorLabels" . | nindent 6 }}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    {{- with .Values.networkPolicy.ingressFrom }}
    - from:
        {{- toYaml . | nindent 8 }}
      ports:
        - port: {{ $.Values.service.targetPort }}
          protocol: TCP
    {{- end }}
  egress:
    # Allow DNS resolution to kube-dns.
    - to:
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
    {{- with .Values.networkPolicy.egressTo }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
{{- end }}
{{- end -}}
