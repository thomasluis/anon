#!/bin/bash
set -u


DATADIR=./benchmark-datadir
SHA256CMD="$(command -v sha256sum || echo shasum)"
SHA256ARGS="$(command -v sha256sum >/dev/null || echo '-a 256')"

function zcash_rpc {
    ./src/anon-cli -datadir="$DATADIR" -rpcuser=user -rpcpassword=password -rpcport=5983 "$@"
}

function zcash_rpc_slow {
    # Timeout of 1 hour
    zcash_rpc -rpcclienttimeout=3600 "$@"
}

function zcash_rpc_veryslow {
    # Timeout of 2.5 hours
    zcash_rpc -rpcclienttimeout=9000 "$@"
}

function zcash_rpc_wait_for_start {
    zcash_rpc -rpcwait getinfo > /dev/null
}

function anond_generate {
    zcash_rpc generate 101 > /dev/null
}

function anond_start {
    rm -rf "$DATADIR"
    mkdir -p "$DATADIR/regtest"
    touch "$DATADIR/anon.conf"
    ./src/anond -regtest -datadir="$DATADIR" -rpcuser=user -rpcpassword=password -rpcport=5983 -showmetrics=0 &
    ANOND_PID=$!
    zcash_rpc_wait_for_start
}

function anond_stop {
    zcash_rpc stop > /dev/null
    wait $ANOND_PID
}

function anond_massif_start {
    rm -rf "$DATADIR"
    mkdir -p "$DATADIR/regtest"
    touch "$DATADIR/anon.conf"
    rm -f massif.out
    valgrind --tool=massif --time-unit=ms --massif-out-file=massif.out ./src/anond -regtest -datadir="$DATADIR" -rpcuser=user -rpcpassword=password -rpcport=5983 -showmetrics=0 &
    ANOND_PID=$!
    zcash_rpc_wait_for_start
}

function anond_massif_stop {
    zcash_rpc stop > /dev/null
    wait $ANOND_PID
    ms_print massif.out
}

function anond_valgrind_start {
    rm -rf "$DATADIR"
    mkdir -p "$DATADIR/regtest"
    touch "$DATADIR/anon.conf"
    rm -f valgrind.out
    valgrind --leak-check=yes -v --error-limit=no --log-file="valgrind.out" ./src/anond -regtest -datadir="$DATADIR" -rpcuser=user -rpcpassword=password -rpcport=5983 -showmetrics=0 &
    ANOND_PID=$!
    zcash_rpc_wait_for_start
}

function anond_valgrind_stop {
    zcash_rpc stop > /dev/null
    wait $ANOND_PID
    cat valgrind.out
}

function extract_benchmark_data {
    if [ -f "block-107134.tar.xz" ]; then
        # Check the hash of the archive:
        "$SHA256CMD" $SHA256ARGS -c <<EOF
4bd5ad1149714394e8895fa536725ed5d6c32c99812b962bfa73f03b5ffad4bb  block-107134.tar.xz
EOF
        ARCHIVE_RESULT=$?
    else
        echo "block-107134.tar.xz not found."
        ARCHIVE_RESULT=1
    fi
    if [ $ARCHIVE_RESULT -ne 0 ]; then
        anond_stop
        echo
        echo "Please generate it using qa/zcash/create_benchmark_archive.py"
        echo "and place it in the base directory of the repository."
        echo "Usage details are inside the Python script."
        exit 1
    fi
    xzcat block-107134.tar.xz | tar x -C "$DATADIR/regtest"
}

# Precomputation
case "$1" in
    *)
        case "$2" in
            verifyjoinsplit)
                anond_start
                RAWJOINSPLIT=$(zcash_rpc zcsamplejoinsplit)
                anond_stop
        esac
esac

case "$1" in
    time)
        anond_start
        case "$2" in
            sleep)
                zcash_rpc zcbenchmark sleep 10
                ;;
            parameterloading)
                zcash_rpc zcbenchmark parameterloading 10
                ;;
            createjoinsplit)
                zcash_rpc zcbenchmark createjoinsplit 10 "${@:3}"
                ;;
            verifyjoinsplit)
                zcash_rpc zcbenchmark verifyjoinsplit 1000 "\"$RAWJOINSPLIT\""
                ;;
            solveequihash)
                zcash_rpc_slow zcbenchmark solveequihash 50 "${@:3}"
                ;;
            verifyequihash)
                zcash_rpc zcbenchmark verifyequihash 1000
                ;;
            validatelargetx)
                zcash_rpc zcbenchmark validatelargetx 5
                ;;
            trydecryptnotes)
                zcash_rpc zcbenchmark trydecryptnotes 1000 "${@:3}"
                ;;
            incnotewitnesses)
                zcash_rpc zcbenchmark incnotewitnesses 100 "${@:3}"
                ;;
            connectblockslow)
                extract_benchmark_data
                zcash_rpc zcbenchmark connectblockslow 10
                ;;
            *)
                anond_stop
                echo "Bad arguments."
                exit 1
        esac
        anond_stop
        ;;
    memory)
        anond_massif_start
        case "$2" in
            sleep)
                zcash_rpc zcbenchmark sleep 1
                ;;
            parameterloading)
                zcash_rpc zcbenchmark parameterloading 1
                ;;
            createjoinsplit)
                zcash_rpc_slow zcbenchmark createjoinsplit 1 "${@:3}"
                ;;
            verifyjoinsplit)
                zcash_rpc zcbenchmark verifyjoinsplit 1 "\"$RAWJOINSPLIT\""
                ;;
            solveequihash)
                zcash_rpc_slow zcbenchmark solveequihash 1 "${@:3}"
                ;;
            verifyequihash)
                zcash_rpc zcbenchmark verifyequihash 1
                ;;
            trydecryptnotes)
                zcash_rpc zcbenchmark trydecryptnotes 1 "${@:3}"
                ;;
            incnotewitnesses)
                zcash_rpc zcbenchmark incnotewitnesses 1 "${@:3}"
                ;;
            connectblockslow)
                extract_benchmark_data
                zcash_rpc zcbenchmark connectblockslow 1
                ;;
            *)
                anond_massif_stop
                echo "Bad arguments."
                exit 1
        esac
        anond_massif_stop
        rm -f massif.out
        ;;
    valgrind)
        anond_valgrind_start
        case "$2" in
            sleep)
                zcash_rpc zcbenchmark sleep 1
                ;;
            parameterloading)
                zcash_rpc zcbenchmark parameterloading 1
                ;;
            createjoinsplit)
                zcash_rpc_veryslow zcbenchmark createjoinsplit 1 "${@:3}"
                ;;
            verifyjoinsplit)
                zcash_rpc zcbenchmark verifyjoinsplit 1 "\"$RAWJOINSPLIT\""
                ;;
            solveequihash)
                zcash_rpc_veryslow zcbenchmark solveequihash 1 "${@:3}"
                ;;
            verifyequihash)
                zcash_rpc zcbenchmark verifyequihash 1
                ;;
            trydecryptnotes)
                zcash_rpc zcbenchmark trydecryptnotes 1 "${@:3}"
                ;;
            incnotewitnesses)
                zcash_rpc zcbenchmark incnotewitnesses 1 "${@:3}"
                ;;
            connectblockslow)
                extract_benchmark_data
                zcash_rpc zcbenchmark connectblockslow 1
                ;;
            *)
                anond_valgrind_stop
                echo "Bad arguments."
                exit 1
        esac
        anond_valgrind_stop
        rm -f valgrind.out
        ;;
    valgrind-tests)
        case "$2" in
            gtest)
                rm -f valgrind.out
                valgrind --leak-check=yes -v --error-limit=no --log-file="valgrind.out" ./src/zcash-gtest
                cat valgrind.out
                rm -f valgrind.out
                ;;
            test_bitcoin)
                rm -f valgrind.out
                valgrind --leak-check=yes -v --error-limit=no --log-file="valgrind.out" ./src/test/test_bitcoin
                cat valgrind.out
                rm -f valgrind.out
                ;;
            *)
                echo "Bad arguments."
                exit 1
        esac
        ;;
    *)
        echo "Bad arguments."
        exit 1
esac

# Cleanup
rm -rf "$DATADIR"
