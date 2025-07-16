#!/bin/bash

echo "Test script running..."

case "${1:-}" in
    --help|-h)
        echo "Help message works"
        exit 0
        ;;
    --dry-run)
        echo "Dry run mode works"
        exit 0
        ;;
    *)
        echo "Default case works"
        ;;
esac

echo "Script completed."
