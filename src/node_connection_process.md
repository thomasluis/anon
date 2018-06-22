Regular Node Connections
First regular node will try to connect,
    threadGroup.create_thread(boost::bind(&TraceThread<void (*)()>, "opencon", &ThreadOpenConnections));
Then they will run ThreadOpenConnections


Masternode Connections
Thread 16 "anon-masternode" hit Breakpoint 1, ConnectNode (addrConnect=..., pszDest=pszDest@entry=0x0,
    fConnectToMasternode=fConnectToMasternode@entry=true) at net.cpp:367