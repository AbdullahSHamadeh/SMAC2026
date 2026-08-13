"""Issue an expiring local development token from the configured secret."""

import argparse
import os
from uuid import UUID

from .auth import issue_dev_token


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("user_id", type=UUID)
    parser.add_argument("--ttl", type=int, default=3_600, help="Lifetime in seconds")
    args = parser.parse_args()
    secret = os.getenv("FAMILY_COMPASS_DEV_AUTH_SECRET", "")
    print(issue_dev_token(args.user_id, secret, ttl_seconds=args.ttl))


if __name__ == "__main__":
    main()
