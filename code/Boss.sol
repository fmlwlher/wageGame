pragma solidity ^0.8.0;
import "./Ownable.sol";
import "./Pausable.sol";
import "./ERC721Enumerable.sol";
import "./IBoss.sol";
import "./ICompany.sol";
import "./ITraits.sol";
import "./WAG.sol";

interface RandomPicker {
    function getRandom(uint256 seed) external view returns (uint256);
    function addNonce() external;
}
contract Boss is IBoss, ERC721Enumerable, Ownable, Pausable {
  RandomPicker public random;

  // mint price1
  uint256 public constant MINT_PRICE1 = .08 ether;
  
  // mint price2
  uint256 public constant MINT_PRICE2 = .13 ether;
  // max number of tokens that can be minted - 50000 in production
  uint256 public immutable MAX_TOKENS;
  // number of tokens that can be claimed for free - 1000 
  uint256 public PRE_PAID_TOKENS;
  // number of tokens that can be claimed for free - 20% of MAX_TOKENS
  uint256 public PAID_TOKENS;
  // number of tokens have been minted so far
  uint16 public minted;
  

  // mapping from tokenId to a struct containing the token's traits
  mapping(uint256 => EmployeeBoss) public tokenTraits;
  // mapping from hashed(tokenTrait) to the tokenId it's associated with
  // used to ensure there are no duplicates
  mapping(uint256 => uint256) public existingCombinations;

  // list of probabilities for each trait type
  // 0 - 9 are associated with Programmer, 10 - 18 are associated with Bosses
  uint8[][18] public rarities;
  // list of aliases for Walker's Alias algorithm
  // 0 - 9 are associated with Programmer, 10 - 18 are associated with Bosses
  uint8[][18] public aliases;

  // reference to the Company for choosing random Boss thieves
  ICompany public company;
  // reference to $WAG for burning on mint
  WAG public wag;
  // reference to Traits
  ITraits public traits;

  uint256 public programmerMinted;
  uint256 public programmerStolen;
  uint256 public bossMinted;
  uint256 public bossStaked;
  uint256 public bossesStolen;


  /** 
   * instantiates contract and rarity tables
   */
  constructor(address _wag, address _traits, uint256 _maxTokens) ERC721("Boss Game", 'BGAME') { 
    wag = WAG(_wag);
    traits = ITraits(_traits);
    MAX_TOKENS = _maxTokens;
    PRE_PAID_TOKENS = 1000;
    PAID_TOKENS = _maxTokens / 5;

    // I know this looks weird but it saves users gas by making lookup O(1)
    // A.J. Walker's Alias Algorithm
    // programmer
    // fur
    rarities[0] = [15, 50, 200, 250, 255];
    aliases[0] = [4, 4, 4, 4, 4];
    // head
    rarities[1] = [190, 215, 240, 100, 110, 135, 160, 185, 80, 210, 235, 240, 80, 80, 100, 100, 100, 245, 250, 255];
    aliases[1] = [1, 2, 4, 0, 5, 6, 7, 9, 0, 10, 11, 17, 0, 0, 0, 0, 4, 18, 19, 19];
    // ears
    rarities[2] =  [255, 30, 60, 60, 150, 156];
    aliases[2] = [0, 0, 0, 0, 0, 0];
    // eyes
    rarities[3] = [221, 100, 181, 140, 224, 147, 84, 228, 140, 224, 250, 160, 241, 207, 173, 84, 254, 220, 196, 140, 168, 252, 140, 183, 236, 252, 224, 255];
    aliases[3] = [1, 2, 5, 0, 1, 7, 1, 10, 5, 10, 11, 12, 13, 14, 16, 11, 17, 23, 13, 14, 17, 23, 23, 24, 27, 27, 27, 27];
    // bg
    rarities[4] = [175, 100, 40, 250, 115, 100, 185, 175, 180, 255];
    aliases[4] = [3, 0, 4, 6, 6, 7, 8, 8, 9, 9];
    // mouth
    rarities[5] = [80, 225, 227, 228, 112, 240, 64, 160, 167, 217, 171, 64, 240, 126, 80, 255];
    aliases[5] = [1, 2, 3, 8, 2, 8, 8, 9, 9, 10, 13, 10, 13, 15, 13, 15];
    // neck
    rarities[6] = [255];
    aliases[6] = [0];
    // cloth
    rarities[7] = [243, 189, 133, 133, 57, 95, 152, 135, 133, 57, 222, 168, 57, 57, 38, 114, 114, 114, 255];
    aliases[7] = [1, 7, 0, 0, 0, 0, 0, 10, 0, 0, 11, 18, 0, 0, 0, 1, 7, 11, 18];
    // alphaIndex
    rarities[8] = [255];
    aliases[8] = [0];

    // Bosses
    // fur
    rarities[9] = [210, 90, 9, 9, 9, 150, 9, 255, 9];
    aliases[9] = [5, 0, 0, 5, 5, 7, 5, 7, 5];
    // head
    rarities[10] = [255];
    aliases[10] = [0];
    // ears
    rarities[11] = [255];
    aliases[11] = [0];
    // eyes
    rarities[12] = [135, 177, 219, 141, 183, 225, 147, 189, 231, 135, 135, 135, 135, 246, 150, 150, 156, 165, 171, 180, 186, 195, 201, 210, 243, 252, 255];
    aliases[12] = [1, 2, 3, 4, 5, 6, 7, 8, 13, 3, 6, 14, 15, 16, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 26, 26];
    // bg
    rarities[13] = [255];
    aliases[13] = [0];
    // mouth
    rarities[14] = [239, 244, 249, 234, 234, 234, 234, 234, 234, 234, 130, 255, 247];
    aliases[14] = [1, 2, 11, 0, 11, 11, 11, 11, 11, 11, 11, 11, 11];
    // neck
    rarities[15] = [255];
    aliases[15] = [0];
    // cloth 
    rarities[16] = [255];
    aliases[16] = [0];
    // alphaIndex
    rarities[17] = [8, 160, 73, 255]; 
    aliases[17] = [2, 3, 3, 3];
  }

  /** EXTERNAL */

  /** 
   * mint a token - 90% Programmer, 10% Boss
   * The first 20% are free to claim, the remaining cost $WAG
   */
  function mint(uint256 amount, bool stake) external payable whenNotPaused {
    require(tx.origin == _msgSender(), "Only EOA");
    require(minted + amount <= MAX_TOKENS, "All tokens minted");
    require(amount > 0 && amount <= 10, "Invalid mint amount");
    if (minted < PRE_PAID_TOKENS) {
      require(minted + amount <= PRE_PAID_TOKENS, "All tokens of price1 on-sale already sold");
      require(amount * MINT_PRICE1 == msg.value, "Invalid payment amount");  
    } else if (minted < PAID_TOKENS) {
      require(minted + amount <= PAID_TOKENS, "All tokens on-sale already sold");
      require(amount * MINT_PRICE2 == msg.value, "Invalid payment amount");
    } else {
      require(msg.value == 0);
    }

    uint256 totalWagCost = 0;
    uint16[] memory tokenIds = stake ? new uint16[](amount) : new uint16[](0);
    uint256 seed;
    for (uint i = 0; i < amount; i++) {
      minted++;
      random.addNonce();
      seed = random.getRandom(minted);
      //seed = random(minted);
      
      address recipient = selectRecipient(seed);
      statistics((seed & 0xFFFF) % 10 != 0, stake, recipient != _msgSender());
      if (!stake || recipient != _msgSender()) {
        _safeMint(recipient, minted);
      } else {
        _safeMint(address(company), minted);
        tokenIds[i] = minted;
      }
      generate(minted, seed);
      totalWagCost += mintCost(minted);
    }
    
    if (totalWagCost > 0) wag.burn(_msgSender(), totalWagCost);
    if (stake) company.addManyToBarnAndPack(_msgSender(), tokenIds);
  }

  function statistics(bool isProgrammer, bool stake, bool stolen) internal {
     if (isProgrammer) {
       programmerMinted++;
       if (stolen) {
         programmerStolen++;
       }
     }else {
       bossMinted++;
       if (stake) {
         bossStaked++;
       }
       if (stolen) {
         bossesStolen++;
       }
     } 
  }

  /** 
   * the first 20% are paid in ETH
   * the next 20% are 20000 $WAG
   * the next 40% are 40000 $WAG
   * the final 20% are 80000 $WAG
   * @param tokenId the ID to check the cost of to mint
   * @return the cost of the given token ID
   */
  function mintCost(uint256 tokenId) public view returns (uint256) {
    if (tokenId <= PAID_TOKENS) return 0;
    if (tokenId <= MAX_TOKENS * 2 / 5) return 20000 ether;
    if (tokenId <= MAX_TOKENS * 4 / 5) return 40000 ether;
    return 80000 ether;
  }

  function transferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public virtual override {
    // Hardcode the Company's approval so that users don't have to waste gas approving
    if (_msgSender() != address(company))
      require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
    _transfer(from, to, tokenId);
  }

  /** INTERNAL */

  /**
   * generates traits for a specific token, checking to make sure it's unique
   * @param tokenId the id of the token to generate traits for
   * @param seed a pseudorandom 256 bit number to derive traits from
   * @return t - a struct of traits for the given token ID
   */
  function generate(uint256 tokenId, uint256 seed) internal returns (EmployeeBoss memory t) {
    t = selectTraits(seed);
    if (existingCombinations[structToHash(t)] == 0) {
      tokenTraits[tokenId] = t;
      existingCombinations[structToHash(t)] = tokenId;
      return t;
    }
    return generate(tokenId, random.getRandom(seed));
  }

  /**
   * uses A.J. Walker's Alias algorithm for O(1) rarity table lookup
   * ensuring O(1) instead of O(n) reduces mint cost by more than 50%
   * probability & alias tables are generated off-chain beforehand
   * @param seed portion of the 256 bit seed to remove trait correlation
   * @param traitType the trait type to select a trait for 
   * @return the ID of the randomly selected trait
   */
  function selectTrait(uint16 seed, uint8 traitType) internal view returns (uint8) {
    uint8 trait = uint8(seed) % uint8(rarities[traitType].length);
    if (seed >> 8 < rarities[traitType][trait]) return trait;
    return aliases[traitType][trait];
  }

  /**
   * the first 20% (ETH purchases) go to the minter
   * the remaining 80% have a 10% chance to be given to a random staked boss
   * @param seed a random value to select a recipient from
   * @return the address of the recipient (either the minter or the Boss thief's owner)
   */
  function selectRecipient(uint256 seed) internal view returns (address) {
    if (minted <= PAID_TOKENS || ((seed >> 245) % 10) != 0) return _msgSender(); // top 10 bits haven't been used
    address thief = company.randomBossOwner(seed >> 144); // 144 bits reserved for trait selection
    if (thief == address(0x0)) return _msgSender();
    return thief;
  }

  /**
   * selects the species and all of its traits based on the seed value
   * @param seed a pseudorandom 256 bit number to derive traits from
   * @return t -  a struct of randomly selected traits
   */
  function selectTraits(uint256 seed) internal view returns (EmployeeBoss memory t) {    
    t.isEmployee = (seed & 0xFFFF) % 10 != 0;
    uint8 shift = t.isEmployee ? 0 : 9;
    seed >>= 16;
    t.fur = selectTrait(uint16(seed & 0xFFFF), 0 + shift);
    seed >>= 16;
    t.head = selectTrait(uint16(seed & 0xFFFF), 1 + shift);
    seed >>= 16;
    t.ears = selectTrait(uint16(seed & 0xFFFF), 2 + shift);
    seed >>= 16;
    t.eyes = selectTrait(uint16(seed & 0xFFFF), 3 + shift);
    seed >>= 16;
    t.bg = selectTrait(uint16(seed & 0xFFFF), 4 + shift);
    seed >>= 16;
    t.mouth = selectTrait(uint16(seed & 0xFFFF), 5 + shift);
    seed >>= 16;
    t.neck = selectTrait(uint16(seed & 0xFFFF), 6 + shift);
    seed >>= 16;
    t.cloth = selectTrait(uint16(seed & 0xFFFF), 7 + shift);
    seed >>= 16;
    t.alphaIndex = selectTrait(uint16(seed & 0xFFFF), 8 + shift);
  }

  /**
   * converts a struct to a 256 bit hash to check for uniqueness
   * @param s the struct to pack into a hash
   * @return the 256 bit hash of the struct
   */
  function structToHash(EmployeeBoss memory s) internal pure returns (uint256) {
    return uint256(bytes32(
      abi.encodePacked(
        s.isEmployee,
        s.fur,
        s.head,
        s.eyes,
        s.mouth,
        s.neck,
        s.ears,
        s.cloth,
        s.bg,
        s.alphaIndex
      )
    ));
  }

  /**
   * generates a pseudorandom number
   * @param seed a value ensure different outcomes for different sources in the same block
   * @return a pseudorandom value
   */
  /*function random(uint256 seed) internal view returns (uint256) {
    return uint256(keccak256(abi.encodePacked(
      tx.origin,
      blockhash(block.number - 1),
      block.timestamp,
      seed
    )));
  }*/

  /** READ */

  function getTokenTraits(uint256 tokenId) external view override returns (EmployeeBoss memory) {
    return tokenTraits[tokenId];
  }

  function getPaidTokens() external view override returns (uint256) {
    return PAID_TOKENS;
  }

  /** ADMIN */

  /**
   * called after deployment so that the contract can get random boss thieves
   * @param _company the address of the Company
   */
  function setCompany(address _company) external onlyOwner {
    company = ICompany(_company);
  }

  function setRandomAddress(address _address) external onlyOwner {
      random = RandomPicker(_address);
  }

  /**
   * allows owner to withdraw funds from minting
   */
  function withdraw() external onlyOwner {
    payable(owner()).transfer(address(this).balance);
  }

  /**
   * updates the number of tokens for sale
   */
  function setPaidTokens(uint256 _paidTokens) external onlyOwner {
    PAID_TOKENS = _paidTokens;
  }

  /**
   * enables owner to pause / unpause minting
   */
  function setPaused(bool _paused) external onlyOwner {
    if (_paused) _pause();
    else _unpause();
  }

  /** RENDER */

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
    return traits.tokenURI(tokenId);
  }
}