{config, pkgs, lib, ...}:

with lib;

let
   cfg = config.services.ethConductor;
   rungeth = pkgs.writeScriptBin "rungeth" ''
    #!${pkgs.stdenv.shell}
    PATH="${pkgs.go-ethereum}/bin:${pkgs.coreutils}/bin:${pkgs.jq}/bin:$PATH"
    cd $STATE_DIRECTORY
    if [[ ! -f genesis.json ]]; then
      echo "password" > pw;
      geth --datadir . --password pw account new
      address=$(cat ./keystore/UTC*|jq -r ".address")
      echo $address > address
      echo '{
        "config":{
          "chainId":31317,
          "homesteadBlock":0,
          "eip150Block":0,
          "eip150Hash":"0x0000000000000000000000000000000000000000000000000000000000000000",
          "eip155Block":0,
          "eip158Block":0,
          "byzantiumBlock":0,
          "constantinopleBlock":0,
          "petersburgBlock":0,
          "istanbulBlock":0,
          "clique":{"period":0,"epoch":30000}
        },
        "nonce":"0x0",
        "timestamp":"0x602073f5",
        "extraData":"0x0000000000000000000000000000000000000000000000000000000000000000'$address'0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "gasLimit":"0x47b760",
        "difficulty":"0x1",
        "mixHash":"0x0000000000000000000000000000000000000000000000000000000000000000",
        "coinbase":"0x0000000000000000000000000000000000000000",
        "alloc":{
          "aa93b3155442052d23c9b9b7fd26d02733016078": {
            "balance":"0x200000000000000000000000000000000000000000000000000000000000000"
            },
          "'$address'": {
            "balance": "0x200000000000000000000000000000000000000000000000000000000000000"
          }
        },
        "number":"0x0",
        "gasUsed":"0x0",
        "parentHash":"0x0000000000000000000000000000000000000000000000000000000000000000"
        }'> genesis.json
      geth --datadir . init genesis.json
    fi
    echo "---run---"
    geth --datadir .                                 \
    --syncmode 'full'                                \
    --port 30311                                     \
    --http --http.addr '0.0.0.0' --http.port 8501 \
    --http.api 'personal,eth,net,web3,txpool,miner'  \
    --http.corsdomain '*'                            \
    --networkid 31317                                \
    --miner.gasprice '1'                             \
    --miner.etherbase "$(cat address)"               \
    --mine                                           \
    -unlock "$(cat address)" --password pw           \
    --allow-insecure-unlock'';
in
{
  options = {
    services.ethConductor = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = ''
          Start a geth conductor service
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.ethConductorSession = {
      wantedBy = [ "default.target" ];
      after = [ "network.target" ];
      description = "Start the geth daemon";
      serviceConfig = {
        Type = "simple";
        User="mhhf";
        Environment = [
          "HOME=%S/eth-conductor"
        ];
        ExecStart = ''${rungeth}/bin/rungeth'';
        StateDirectory = "eth-conductor";
        WorkingDirectory = "%S/eth-conductor";
      };
      # Restart = "always";
    };

    environment.systemPackages = [
      pkgs.go-ethereum
      pkgs.jq
      rungeth
    ];
  };
}
