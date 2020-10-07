{{- define "hubble-generate-certs.job.spec" }}
{{- $certValiditySecondsStr := printf "%ds" (mul .Values.global.hubble.tls.auto.certValidityDuration 24 60 60) -}}
spec:
  template:
    metadata:
      labels:
        k8s-app: {{ .Chart.Name }}
    spec:
      serviceAccount: hubble-generate-certs-sa
      serviceAccountName: hubble-generate-certs-sa
      containers:
        - name: certgen
          {{- if contains "/" .Values.cronJob.image.repository }}
          image: "{{ .Values.cronJob.image.repository }}"
          {{- else }}
          image: "{{ .Values.global.registry }}/{{ .Values.cronJob.image.repository }}:{{ .Values.cronJob.image.tag }}"
          {{- end }}
          imagePullPolicy: {{ .Values.global.pullPolicy }}
          command:
            - "/usr/bin/cilium-certgen"
          {{/* Because this is executed as a job, we pass the values as command line args instead of via config map,
                this allows users to inspect the values used in past runs by inspecting the completed pod */ -}}
          args:
            {{- if .Values.global.debug.enabled }}
            - "--debug"
            {{- end }}
            {{- $hubbleCAProvided := and .Values.ca.crt .Values.ca.key -}}
            {{- if $hubbleCAProvided }}
            - "--hubble-ca-generate=false"
            - "--hubble-ca-key-file=/var/lib/cilium/tls/hubble-ca/tls.key"
            - "--hubble-ca-cert-file=/var/lib/cilium/tls/hubble-ca/tls.crt"
            {{- else }}
            - "--hubble-ca-generate=true"
            - "--hubble-ca-validity-duration={{ $certValiditySecondsStr }}"
            - "--hubble-ca-config-map-name=hubble-ca-cert"
            - "--hubble-ca-config-map-namespace={{ .Release.Namespace }}"
            {{- end }}
            {{- if and .Values.server.crt .Values.server.key $hubbleCAProvided }}
            - "--hubble-server-cert-generate=false"
            {{- else }}
            - "--hubble-server-cert-generate=true"
            - "--hubble-server-cert-validity-duration={{ $certValiditySecondsStr }}"
            - "--hubble-server-cert-secret-name=hubble-server-certs"
            - "--hubble-server-cert-secret-namespace={{ .Release.Namespace }}"
            {{- end }}
            {{- if and .Values.relay.client.crt .Values.relay.client.key $hubbleCAProvided }}
            - "--hubble-relay-client-cert-generate=false"
            {{- else }}
            - "--hubble-relay-client-cert-generate=true"
            - "--hubble-relay-client-cert-validity-duration={{ $certValiditySecondsStr }}"
            - "--hubble-relay-client-cert-secret-name=hubble-relay-client-certs"
            - "--hubble-relay-client-cert-secret-namespace={{ .Release.Namespace }}"
            {{- end }}
            {{- if or (and .Values.relay.server.crt .Values.relay.server.key) (not .Values.global.hubble.relay.tls.enabled) }}
            - "--hubble-relay-server-cert-generate=false"
            {{- else if .Values.global.hubble.relay.tls.enabled }}
            - "--hubble-relay-client-cert-generate=true"
            - "--hubble-relay-server-cert-validity-duration={{ $certValiditySecondsStr }}"
            - "--hubble-relay-server-cert-secret-name=hubble-relay-server-certs"
            - "--hubble-relay-server-cert-secret-namespace={{ .Release.Namespace }}"
            {{- end }}
          volumeMounts:
          {{- if $hubbleCAProvided }}
            - mountPath: /var/lib/cilium/tls/hubble-ca
              name: hubble-ca-secret
              readOnly: true
          {{- end }}
      hostNetwork: true
      restartPolicy: OnFailure
      volumes:
      {{- if $hubbleCAProvided }}
        - name: hubble-ca-secret
          secret:
            secretName: hubble-ca-secret
      {{- end }}
  ttlSecondsAfterFinished: {{ .Values.cronJob.ttlSecondsAfterFinished }}
{{- end }}