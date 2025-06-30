# CPU Recommendations for 6 Quality Presets (Including 4K)

## Executive Summary

For **all 6 quality levels including 4K**, you need **minimum 16 vCPUs** for 1 concurrent stream.

## Detailed CPU Analysis

### CPU Requirements per Quality Level

| Quality | Resolution | Bitrate | Encoding Complexity | CPU Usage (vCPUs) |
|---------|------------|---------|--------------------|--------------------|
| 360p    | 640x360    | 400k    | Low                | ~0.4               |
| 480p    | 854x480    | 800k    | Low-Medium         | ~0.6               |
| 720p    | 1280x720   | 1.5M    | Medium             | ~1.0               |
| 1080p   | 1920x1080  | 3M      | High               | ~2.0               |
| 1440p   | 2560x1440  | 6M      | Very High          | ~3.5               |
| **4K**  | 3840x2160  | 12M     | **Extreme**        | **~5.5**           |

**Total per stream**: ~13 vCPUs  
**System overhead**: ~2 vCPUs  
**Required per stream**: **~15 vCPUs**

## AWS Instance Recommendations

### Single Stream Scenarios

#### Option 1: c6g.4xlarge (Minimum)
- **Specs**: 16 vCPU, 32GB RAM
- **Cost**: $0.544/hour ($392/month)
- **Performance**: 85-95% CPU utilization
- **Pros**: Lowest cost for 6 qualities
- **Cons**: High CPU usage, no room for spikes
- **Verdict**: ⚠️ **Risky but functional**

#### Option 2: c6g.8xlarge (Recommended)
- **Specs**: 32 vCPU, 64GB RAM  
- **Cost**: $1.088/hour ($784/month)
- **Performance**: 45-55% CPU utilization
- **Pros**: Comfortable headroom, stable performance
- **Cons**: Higher cost
- **Verdict**: ✅ **Best balance for production**

### Multiple Stream Scenarios

#### 2 Concurrent Streams
**Minimum**: c6g.8xlarge (32 vCPU) - 90-95% CPU usage ⚠️  
**Recommended**: c6g.12xlarge (48 vCPU) - 60-70% CPU usage ✅

#### 3 Concurrent Streams  
**Minimum**: c6g.12xlarge (48 vCPU) - 90-95% CPU usage ⚠️  
**Recommended**: c6g.16xlarge (64 vCPU) - 65-75% CPU usage ✅

#### 4+ Concurrent Streams
**Required**: c6g.16xlarge (64 vCPU) or multiple smaller instances

## Cost Comparison Table

| Instance Type | vCPUs | RAM | Hourly Cost | Monthly Cost | Max Streams (Safe) |
|---------------|-------|-----|-------------|--------------|-------------------|
| c6g.xlarge    | 4     | 8GB | $0.136      | $98          | 0 (insufficient)  |
| c6g.2xlarge   | 8     | 16GB| $0.272      | $196         | 0 (insufficient)  |
| c6g.4xlarge   | 16    | 32GB| $0.544      | $392         | 1 (tight)         |
| c6g.8xlarge   | 32    | 64GB| $1.088      | $784         | 1-2               |
| c6g.12xlarge  | 48    | 96GB| $1.632      | $1,176       | 2-3               |
| c6g.16xlarge  | 64    | 128GB| $2.176     | $1,568       | 3-4               |

*Prices are for US East (N. Virginia) region, on-demand pricing*

## Alternative Approaches

### 1. Reduce Quality Levels (Cost-Effective)

Instead of 6 qualities, consider:

**3 Quality Setup** (Recommended for budget):
- 720p (1.5M bitrate) - ~1 vCPU
- 1080p (3M bitrate) - ~2 vCPU  
- 4K (12M bitrate) - ~5.5 vCPU
- **Total**: ~8.5 vCPUs + overhead = **~11 vCPUs**
- **Instance**: c6g.4xlarge (16 vCPU) - comfortable fit
- **Cost savings**: Same instance, better performance

**4 Quality Setup** (Good balance):
- 480p, 720p, 1080p, 4K
- **Total**: ~9.5 vCPUs + overhead = **~12 vCPUs**
- **Instance**: c6g.4xlarge (16 vCPU) - good fit

### 2. Hardware Encoding (If Available)

**Note**: AWS Graviton2 doesn't have hardware video encoding, but Intel instances do:

**c6i.4xlarge** (Intel with Quick Sync):
- Hardware encoding can reduce CPU usage by 60-80%
- 4K encoding: ~1.5 vCPU instead of 5.5 vCPU
- **Total for 6 qualities**: ~6 vCPUs instead of 13 vCPUs
- **Trade-off**: Slightly lower quality, but much more efficient

### 3. Distributed Encoding

**Multiple smaller instances** instead of one large:

**Option A**: 2x c6g.4xlarge
- **Total**: 32 vCPUs across 2 instances
- **Cost**: $0.544 × 2 = $1.088/hour (same as c6g.8xlarge)
- **Benefit**: Better fault tolerance, can handle 2 streams independently

**Option B**: 4x c6g.2xlarge  
- **Total**: 32 vCPUs across 4 instances
- **Cost**: $0.272 × 4 = $1.088/hour
- **Benefit**: Maximum fault tolerance, geographic distribution

## My Specific Recommendations

### For Testing/Development
**c6g.4xlarge** (16 vCPU, 32GB RAM)
- Can handle 1 stream with all 6 qualities
- $392/month
- Monitor CPU closely

### For Production (1-2 streams)
**c6g.8xlarge** (32 vCPU, 64GB RAM)  
- Comfortable performance
- Room for traffic spikes
- $784/month

### For High-Volume Production (3+ streams)
**c6g.16xlarge** (64 vCPU, 128GB RAM)
- Can handle 3-4 concurrent streams
- Enterprise-grade performance
- $1,568/month

### Budget-Conscious Alternative
**Reduce to 4 quality levels** + **c6g.4xlarge**
- Remove 360p and 1440p (keep 480p, 720p, 1080p, 4K)
- Same instance cost but better performance
- Still covers all major use cases

## Cost Optimization Strategies

### 1. Spot Instances
- **Savings**: 60-70% cost reduction
- **Risk**: Can be terminated with 2-minute notice
- **Best for**: Development, testing, non-critical workloads

### 2. Reserved Instances
- **Savings**: 30-60% for 1-3 year commitments
- **Best for**: Predictable production workloads

### 3. Scheduled Scaling
- Scale down during low-usage hours
- Use smaller instances during off-peak times
- **Potential savings**: 30-50%

### 4. Regional Pricing
- Some regions are 10-20% cheaper
- Consider latency impact for your users

## Performance Monitoring Recommendations

### CPU Thresholds
- **Green**: <70% CPU usage
- **Yellow**: 70-85% CPU usage  
- **Red**: >85% CPU usage (scale up immediately)

### Memory Requirements
- **Minimum**: 2GB RAM per vCPU
- **Recommended**: 4GB RAM per vCPU for video encoding
- **4K encoding**: Requires more memory buffering

### Network Bandwidth
- **4K stream**: ~12 Mbps upload + ~72 Mbps download (6 qualities)
- **Multiple streams**: Multiply accordingly
- **AWS network**: c6g instances have up to 25 Gbps network performance

## Final Recommendation

**For your specific use case (6 qualities including 4K):**

1. **Start with c6g.8xlarge** (32 vCPU, 64GB RAM)
2. **Monitor performance** with the provided monitoring scripts
3. **Scale up to c6g.12xlarge** if you need 2+ concurrent streams
4. **Consider reducing to 4 qualities** if budget is a concern

**Why c6g.8xlarge is the sweet spot:**
- ✅ Handles 1 stream comfortably (50% CPU usage)
- ✅ Can burst to 2 streams if needed (90% CPU usage)
- ✅ Good price/performance ratio
- ✅ Room for system overhead and traffic spikes
- ✅ Production-ready stability

The extra cost over c6g.4xlarge ($392 more/month) is worth it for the stability and headroom you get.
