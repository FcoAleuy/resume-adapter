"""
Storage abstraction: local filesystem (dev) or Supabase Storage (prod).

Supabase is used when SUPABASE_URL + SUPABASE_SERVICE_KEY are set.
All other code should use these functions instead of os/open directly.
"""
import os
import tempfile
from typing import Optional


def _supabase_client():
    from backend.config import get_settings
    settings = get_settings()
    if not settings.supabase_url or not settings.supabase_service_key:
        return None, None
    from supabase import create_client
    client = create_client(settings.supabase_url, settings.supabase_service_key)
    return client, settings.supabase_bucket


def is_remote() -> bool:
    from backend.config import get_settings
    s = get_settings()
    return bool(s.supabase_url and s.supabase_service_key)


def upload_file(contents: bytes, storage_path: str, content_type: str) -> str:
    """
    Upload file contents and return the path to store in DB.
    - Remote: bucket-relative path (e.g. 'uploads/master_abc.docx')
    - Local:  absolute filesystem path
    """
    client, bucket = _supabase_client()
    if client:
        client.storage.from_(bucket).upload(
            storage_path, contents, {"content-type": content_type, "upsert": "true"}
        )
        return storage_path
    else:
        from backend.config import get_settings
        settings = get_settings()
        folder = settings.upload_dir if "upload" in storage_path else settings.output_dir
        os.makedirs(folder, exist_ok=True)
        local_path = os.path.join(folder, os.path.basename(storage_path))
        with open(local_path, "wb") as f:
            f.write(contents)
        return local_path


def download_to_temp(path: str, suffix: str = "") -> str:
    """
    Download file to a temp path and return the temp file path.
    Caller is responsible for deleting the temp file.
    """
    client, bucket = _supabase_client()
    if client:
        contents = client.storage.from_(bucket).download(path)
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=suffix)
        tmp.write(contents)
        tmp.close()
        return tmp.name
    else:
        return path  # already a local path, no copy needed


def delete_file(path: str) -> None:
    client, bucket = _supabase_client()
    if client:
        client.storage.from_(bucket).remove([path])
    else:
        if path and os.path.exists(path):
            os.remove(path)


def get_signed_url(path: str, expires_in: int = 3600) -> Optional[str]:
    """Returns a signed URL for remote storage, None for local (use FileResponse instead)."""
    client, bucket = _supabase_client()
    if client:
        response = client.storage.from_(bucket).create_signed_url(path, expires_in)
        return response.get("signedURL") or response.get("signed_url")
    return None
