-- 回归真实输入队列在慢帧、快速释放和滚轮定位下的天赋树行为。
package.cpath = '../runtime/?.dll;' .. package.cpath
package.path = '../runtime/lua/?.lua;../runtime/lua/?/init.lua;' .. package.path
arg = { }
io.read = function() error('无界面启动失败，禁止等待交互') end
dofile('HeadlessWrapper.lua')
assert(build and not __mainObject__.promptMsg, 'PoB2 初始化失败')
main.userPath = 'Tests/Run/'
newBuild()
local viewer = build.treeTab.viewer
local viewport = { x = 312, y = 32, width = 1608, height = 1000 }
local savedCursor, savedKey = GetCursorPos, IsKeyDown
local cursorX, cursorY, held = 500, 400, false
local assertions = 0
-- 比较可见位移和节点分配结果，误差只允许浮点舍入。
local function equal(actual, expected, label)
	assertions = assertions + 1
	assert(actual == expected or type(actual) == 'number' and type(expected) == 'number' and math.abs(actual-expected)<0.000001,
		label..': '..tostring(actual)..' ~= '..tostring(expected))
end
GetCursorPos = function() return cursorX, cursorY end
IsKeyDown = function(key) return key == 'LEFTBUTTON' and held end
-- 每个场景从相同视图和独立事件队列开始。
local function reset()
	viewer.zoomLevel, viewer.zoom, viewer.zoomX, viewer.zoomY = 3, 1.2^3, 0, 0
	viewer.dragX, viewer.dragY, viewer.dragging = nil, nil, false
	wipeTable(main.inputEvents)
	held = false
end
-- 入队后移动光标，事件仍应保存各自发生时的位置。
reset()
cursorX, cursorY = 500, 400; main:OnKeyDown('LEFTBUTTON')
cursorX, cursorY = 640, 440; main:OnKeyUp('LEFTBUTTON')
equal(main.inputEvents[1].cursorX, 500, '按下事件保存原位置')
equal(main.inputEvents[2].cursorX, 640, '松开事件保存原位置')
cursorX, cursorY = 900, 500
viewer:Draw(build, viewport, main.inputEvents)
equal(viewer.zoomX, 140, '同一帧内完整拖动保留横向位移')
equal(viewer.zoomY, 40, '同一帧内完整拖动保留纵向位移')
equal(viewer.dragging, false, '松开后结束拖动')
equal(viewer.dragX, nil, '松开后清理起点')
-- 按下后还没绘制就移动，第一帧也必须跟随。
reset()
cursorX, cursorY, held = 500, 400, true; main:OnKeyDown('LEFTBUTTON')
cursorX, cursorY = 560, 420
viewer:Draw(build, viewport, main.inputEvents)
equal(viewer.zoomX, 60, '第一帧保留按下后的位移')
equal(viewer.zoomY, 20, '第一帧保留纵向位移')
wipeTable(main.inputEvents)
cursorX, cursorY, held = 590, 450, false; main:OnKeyUp('LEFTBUTTON')
viewer:Draw(build, viewport, main.inputEvents)
equal(viewer.zoomX, 90, '松开帧补齐最后横向位移')
equal(viewer.zoomY, 50, '松开帧补齐最后纵向位移')
-- 从天赋树外按下再移入，不得把侧栏操作变成天赋树拖动。
reset()
cursorX, cursorY, held = 200, 400, true; main:OnKeyDown('LEFTBUTTON')
cursorX, cursorY = 600, 450
viewer:Draw(build, viewport, main.inputEvents)
equal(viewer.zoomX, 0, '树外按下不启动拖动')
-- 丢失松开事件时，实时按键状态仍须解除拖动。
reset()
cursorX, cursorY, held = 500, 400, true; main:OnKeyDown('LEFTBUTTON')
viewer:Draw(build, viewport, main.inputEvents)
wipeTable(main.inputEvents)
cursorX, cursorY = 560, 420; viewer:Draw(build, viewport, main.inputEvents)
held = false; viewer:Draw(build, viewport, main.inputEvents)
equal(viewer.dragging, false, '失去按键状态后解除拖动')
equal(viewer.dragX, nil, '失去按键状态后清理起点')
-- 滚轮已入队后光标离开原点，缩放仍围绕滚轮发生处。
reset()
cursorX, cursorY = 700, 400; main:OnKeyUp('WHEELUP')
cursorX, cursorY = 900, 500
viewer:Draw(build, viewport, main.inputEvents)
equal(viewer.zoomLevel, 4, '滚轮放大一级')
equal(viewer.zoomX, (700-viewport.x-viewport.width/2)*(1-1.2), '缩放保留事件横向锚点')
equal(viewer.zoomY, (400-viewport.y-viewport.height/2)*(1-1.2), '缩放保留事件纵向锚点')
-- 入队后移出天赋树也应保留已经发生的缩放。
reset()
cursorX, cursorY = 700, 400; main:OnKeyUp('WHEELDOWN')
cursorX, cursorY = 100, 400
viewer:Draw(build, viewport, main.inputEvents)
equal(viewer.zoomLevel, 2, '光标离开后仍处理已发生的滚轮')
-- 保留没有坐标字段的旧事件调用方式。
reset()
cursorX, cursorY = 700, 400
viewer:Draw(build, viewport, {{type='KeyUp', key='WHEELUP'}})
equal(viewer.zoomLevel, 4, '旧事件回退当前光标')
-- 单击和阈值内轻微抖动仍可正常分配节点。
reset()
viewer.zoomLevel, viewer.zoom = 0, 1
local target
for _, node in pairs(build.spec.nodes) do
	if node.path and not node.alloc and not node.isAttribute and not node.unlockConstraint and not node.ascendancyName and node.type == 'Normal' then
		local x = viewport.x+viewport.width/2+node.x*viewport.height/build.spec.tree.size
		local y = viewport.y+viewport.height/2+node.y*viewport.height/build.spec.tree.size
		if x>viewport.x+10 and x<viewport.x+viewport.width-10 and y>viewport.y+10 and y<viewport.y+viewport.height-10 then
			target=node; cursorX,cursorY=x,y; break
		end
	end
end
assert(target, '缺少可点击的普通节点')
local targetX,targetY=cursorX,cursorY
cursorX=targetX-2; main:OnKeyDown('LEFTBUTTON')
cursorX=targetX; main:OnKeyUp('LEFTBUTTON')
viewer:Draw(build, viewport, main.inputEvents)
equal(target.alloc, true, '轻微抖动仍正常分配节点')
equal(viewer.zoomX, 0, '轻微抖动不产生平移')
-- 从节点开始拖动后，释放不应被误判成取消分配。
wipeTable(main.inputEvents)
cursorX,cursorY=targetX,targetY; main:OnKeyDown('LEFTBUTTON')
cursorX,cursorY=targetX+20,targetY+10; main:OnKeyUp('LEFTBUTTON')
viewer:Draw(build, viewport, main.inputEvents)
equal(target.alloc, true, '拖动释放不改变已分配节点')
equal(viewer.zoomX, 20, '从节点开始拖动仍完整平移')
-- 经过完整主循环和控件分发，快速拖动仍不能被吞掉。
reset()
build.viewMode = 'TREE'
-- 无界面启动产生的提示弹窗不属于此交互场景。
while main.popups[1] do main:ClosePopup() end
cursorX,cursorY=700,400; main:OnKeyDown('LEFTBUTTON')
cursorX,cursorY=840,440; main:OnKeyUp('LEFTBUTTON')
main:OnFrame()
equal(viewer.zoomX, 140, '完整主循环保留快速拖动')
equal(viewer.zoomY, 40, '完整主循环保留纵向位移')
-- 以实际图片边界验收裁剪，边缘重叠和上下拼接图片不得被误裁。
local savedDrawImage = DrawImage
local drawn = { }
DrawImage = function(handle,x,y,width,height) drawn[#drawn+1]={x,y,width,height} end
local asset = {found=true, width=10, height=20, handle={}}
viewer:DrawAsset(asset, -11, 100, 1)
viewer:DrawAsset(asset, main.screenW+11, 100, 1)
viewer:DrawAsset(asset, 100, -21, 1)
viewer:DrawAsset(asset, 100, main.screenH+21, 1)
equal(#drawn, 0, '完全屏外图片不提交绘制')
viewer:DrawAsset(asset, -5, 100, 1)
equal(#drawn, 1, '部分可见图片仍绘制')
equal(drawn[1][1], -15, '裁剪不改变原图位置')
viewer:DrawAsset(asset, 100, -30, 1, true)
equal(#drawn, 3, '半幅拼接仍保留可见的下半部分')
DrawImage = savedDrawImage
GetCursorPos, IsKeyDown = savedCursor, savedKey
print('PASS: '..assertions..' passive tree interaction assertions')
