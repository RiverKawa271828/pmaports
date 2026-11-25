#!/bin/sh
# cell-mm-rescue.sh — boot 期 MM failed 死锁救援（r81，2026-11-25 P3 蜂窝标准化轮）。
# 背景：mm-dial boot 退役（r80）后，其内嵌的 [1/6] 等 modem + [2/6] failed→
# restart 重扫一并消失——本平台 MM×qcom-soc boot 竞速常态性落 failed（power off，
# r80 reboot 实证：mm-dial 不在 ⇒ 无人救援 ⇒ NM autoconnect 永远 unavailable）。
# 本件 = 把这两段原样拆出为独立 oneshot：只救 modem 状态，不拨号不铺路——
# 数据面仍是 NM 标准形态（MM 恢复 registered 后 NM autoconnect 自己跟上来）。
# 有卡/无卡通吃：failed/sim-missing 重扫一次无害（r75 时代每 boot 都在做）。
LOG=/var/log/cell-keeper.log
log() { echo "$(date '+%m-%d %H:%M:%S') [mm-rescue] $*" >> "$LOG"; }
mm() { timeout 15 mmcli -m any 2>/dev/null | tr -d '\033' | sed 's/\[[0-9;]*m//g'; }
mm_state() { mm | sed -n 's/.*| *state: *//p' | head -1; }
have_modem() { timeout 10 mmcli -L 2>/dev/null | grep -q "Modem/"; }

# keeper 延时 start mpss（r101，boot+~35s）——先等 modem 对象出现（10s×12 = 2min 上限）
i=1
while [ "$i" -le 12 ]; do
	have_modem && break
	sleep 10
	i=$((i + 1))
done
have_modem || { log "no modem object (mpss 未起/keeper 未拉起)——退出不折腾"; exit 0; }

# failed 死锁 → restart 重扫（一百二十配方），最多 2 轮；其余状态零触碰
r=1
while [ "$r" -le 2 ]; do
	ST=$(mm_state)
	[ "$ST" = "failed" ] || { log "state=$ST ok (round $r)"; exit 0; }
	log "state=failed -> restart ModemManager (round $r)"
	systemctl restart ModemManager
	j=1
	while [ "$j" -le 12 ]; do
		have_modem && break
		sleep 10
		j=$((j + 1))
	done
	r=$((r + 1))
done
ST=$(mm_state)
[ "$ST" = "failed" ] && log "STILL failed after 2 rescues (查卡/查 mpss)" && exit 0
log "recovered: state=$ST"
exit 0
