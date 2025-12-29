#!/bin/bash
set -e

cd "$(dirname "$(realpath "$0")")"

echo "=== Building GnuPG 1.4.23 with macOS 14 fixes ==="

# Install required dependencies
echo "Installing dependencies..."
brew install automake autoconf libtool gettext
brew install libgpg-error libgcrypt libassuan libksba pth

# Force gettext to be linked
brew link --force gettext 2>/dev/null || true

# Set compiler flags to be more permissive
export CFLAGS="-O2 -Wall -Wno-deprecated-non-prototype -Wno-unused-but-set-variable -Wno-implicit-function-declaration"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-L$(brew --prefix)/lib"

# Apply inline header fix
echo "Applying inline function fixes..."
cat > inline_fix.h << 'EOF'
#ifndef _GL_INLINE_HEADER_BEGIN
#define _GL_INLINE_HEADER_BEGIN
#define _GL_INLINE_HEADER_END
#endif
EOF

# Apply the xsize.h fix
if [ -f "intl/xsize.h" ]; then
    echo "Patching xsize.h..."
    sed -i '' 's/#error "Please include config.h first."//g' intl/xsize.h
    sed -i '' 's/_GL_INLINE_HEADER_BEGIN//g' intl/xsize.h
    sed -i '' 's/_GL_EXTERN_INLINE//g' intl/xsize.h
fi

# Fix getcwd declaration issue
if [ -f "intl/dcigettext.c" ]; then
    echo "Fixing getcwd declaration..."
    sed -i '' 's/char \*getcwd ();/char *getcwd(char *, size_t);/g' intl/dcigettext.c
fi

# Run autogen if needed
if [ ! -f "configure" ]; then
    echo "Running autogen.sh..."
    ./autogen.sh
fi

# Configure with all necessary flags
echo "Configuring..."
./configure \
    --prefix=/usr/local \
    --with-libgpg-error-prefix=$(brew --prefix libgpg-error) \
    --with-libgcrypt-prefix=$(brew --prefix libgcrypt) \
    --with-libassuan-prefix=$(brew --prefix libassuan) \
    --with-libksba-prefix=$(brew --prefix libksba) \
    --with-pth-prefix=$(brew --prefix pth) \
    --disable-dependency-tracking \
    --disable-silent-rules \
    --disable-asm \
    --enable-static=no \
    --without-included-gettext \
    CFLAGS="$CFLAGS" \
    CXXFLAGS="$CXXFLAGS" \
    LDFLAGS="$LDFLAGS"

# Build
echo "Building..."
make clean 2>/dev/null || true
make -j$(sysctl -n hw.ncpu) 2>&1 | tee build.log

# Check if successful
if [ -f "g10/gpg" ]; then
    echo "=== Build successful! ==="
    ./g10/gpg --version
    echo ""
    echo "To install: sudo make install"
else
    echo "=== Build failed ==="
    echo "Check build.log for details"
fi