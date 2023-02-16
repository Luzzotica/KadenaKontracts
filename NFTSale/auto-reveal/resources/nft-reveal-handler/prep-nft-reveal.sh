
rm function.zip
rm -rf python
mkdir python
pip install -r requirements.txt --platform manylinux2014_x86_64 --only-binary=:all: --no-binary=:none: -t ./python
cd python
zip -r9 ../function.zip .
cd ..
zip -g function.zip lambda_function.py