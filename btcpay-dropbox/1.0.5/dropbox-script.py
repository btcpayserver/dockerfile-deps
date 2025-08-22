#! /usr/bin/python3

import sys
import os
import dropbox
from dropbox.exceptions import ApiError, AuthError
from dropbox.files import WriteMode

# You can generate one for yourself in the App Console.
TOKEN = os.environ.get('DROPBOX_TOKEN')

LOCALFILE = '/data/' + str(sys.argv[1])

file_size = file_size = os.path.getsize(LOCALFILE)

CHUNK_SIZE = 4 * 1024 * 1024

# Check for an access token
if (len(TOKEN) == 0):
    sys.exit("ERROR: Looks like you didn't add your access token.")
print("Creating a Dropbox object...")
dbx = dropbox.Dropbox(TOKEN)
# Check that the access token is valid
try:
    dbx.users_get_current_account()
except AuthError:
    sys.exit("ERROR: Invalid access token; try re-generating an \
            access token from the app console on the web.")
with open(LOCALFILE, 'rb') as f:
    print("Uploading " + LOCALFILE + " to Dropbox ...")
    if file_size <= CHUNK_SIZE:
        print(dbx.files_upload(
            f.read(), f'/{sys.argv[1]}', mode=WriteMode('overwrite')))
    try:
        upload_session_start_result = \
                dbx.files_upload_session_start(f.read(CHUNK_SIZE))
        cursor = dropbox.files.UploadSessionCursor(
                session_id=upload_session_start_result.session_id,
                offset=f.tell())
        commit = dropbox.files.CommitInfo(
                path=f'/{sys.argv[1]}', mode=WriteMode('overwrite'))

        while f.tell() < file_size:
            if ((file_size - f.tell()) <= CHUNK_SIZE):
                print(dbx.files_upload_session_finish(
                        f.read(CHUNK_SIZE), cursor, commit))
            else:
                dbx.files_upload_session_append(f.read(CHUNK_SIZE),
                                                cursor.session_id,
                                                cursor.offset)
                cursor.offset = f.tell()
    except ApiError as err:
        # This checks for the specific error where a user doesn't have
        # enough Dropbox space quota to upload this file
        if (err.error.is_path() and
                err.error.get_path().reason.is_insufficient_space()):
            sys.exit("ERROR: Cannot back up; insufficient space.")
        elif err.user_message_text:
            print(err.user_message_text)
            sys.exit()
        else:
            print(err)
            sys.exit()
