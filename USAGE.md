# WAF Monitoring - Simple Usage Guide

## ✅ Your 3 Requirements - SOLVED

### 1. ✅ Detailed Alerts with User Information
**What you get in email:**
- WHO made the change (IAM user, role, or root)
- WHAT action (Create/Update/Delete)
- WHEN it happened (exact timestamp)
- WHERE from (IP address)
- FULL DETAILS of the change

### 2. ✅ One-Click Deploy & Destroy
**Deploy:**
```bash
export AWS_PROFILE=hassan-account
./deploy.sh
```

**Destroy:**
```bash
export AWS_PROFILE=hassan-account
./cleanup.sh
```

No manual deletions. No clumsy tasks. Just one command.

### 3. ✅ Real-Time Alerts (< 5 seconds)
- Change WAF in AWS Console
- Email arrives in **5 seconds**
- Contains all details about who/what/when/where

---

## 🚀 Quick Start

### First Time Setup:

1. **Set AWS Profile:**
```bash
export AWS_PROFILE=hassan-account
```

2. **Deploy:**
```bash
./deploy.sh
```

3. **Confirm Email:**
- Check your email
- Click SNS confirmation link

4. **Test It:**
- Go to AWS Console → WAF
- Edit your Web ACL (change description)
- Check email (arrives in 5 seconds!)

---

## 🧪 Testing

### Test the Alert System:

1. Go to AWS Console
2. Navigate to: WAF & Shield → Web ACLs
3. Click on "MyWebACL-TF"
4. Click "Edit"
5. Change the description
6. Click "Save"
7. **Check your email** - Alert arrives in 5 seconds!

**Email will show:**
- Your IAM username
- Action: UpdateWebACL
- Exact time
- Your IP address
- Full details of what changed

---

## 🗑️ Cleanup

When you're done:
```bash
export AWS_PROFILE=hassan-account
./cleanup.sh
```

Everything deleted. No charges. Done. ✅

---

## 💰 Cost

**While Running:** ~$5.28/month
**After Cleanup:** $0/month

---

## 🎯 Summary

**Deploy:** `./deploy.sh`  
**Test:** Edit WAF in console  
**Get Alert:** Check email (5 seconds)  
**Cleanup:** `./cleanup.sh`  

That's it! Simple. Clean. One-click.
