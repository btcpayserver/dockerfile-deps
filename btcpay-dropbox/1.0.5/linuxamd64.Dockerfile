FROM python:3.7.2-alpine3.9

RUN pip install dropbox

WORKDIR /btcpay-dropbox

COPY . /btcpay-dropbox

ENTRYPOINT ["python3", "dropbox-script.py"]
