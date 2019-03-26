FROM python:3.7.2-alpine3.9

WORKDIR /btcpay-dropbox

COPY . /btcpay-dropbox

RUN pip install dropbox

ENTRYPOINT ["python3", "dropbox-script.py"]
