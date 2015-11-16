FROM ubuntu
ADD ./ngrok /opt/ngrok
ADD ./run_ngrok.sh /opt/run_ngrok.sh
RUN chmod 777 /opt/ngrok
CMD /opt/ngrok http ${IP_PORT} -log=stdout -log-level=debug
