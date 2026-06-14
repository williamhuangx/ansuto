# -*- coding: utf-8 -*-
"""
安速通物流官网 - Flask后端核心
功能:
  1. MySQL数据库连接
  2. 管理员登录/登出/会话管理
  3. 8大模块CRUD管理后台
  4. 官网前端路由
"""

import os
import pymysql
from datetime import datetime
from functools import wraps
from dotenv import load_dotenv
from flask import (Flask, render_template, request, redirect, url_for,
                   session, flash, jsonify, abort)
from werkzeug.security import generate_password_hash, check_password_hash

load_dotenv()

# Flask应用初始化
app = Flask(__name__,
            template_folder='templates',
            static_folder='static')
app.secret_key = os.environ.get('SECRET_KEY', 'ansuto_admin_secret_key_2024')
app.config['JSON_AS_ASCII'] = False
app.config['PERMANENT_SESSION_LIFETIME'] = 3600 * 8  # 8小时

# ------------------------------------------------------------
# 数据库连接工具 (请求级连接缓存)
# ------------------------------------------------------------
from flask import g

def get_db():
    """获取当前请求的数据库连接, 同一请求内复用"""
    if 'db_conn' not in g:
        g.db_conn = pymysql.connect(
            host=os.environ.get('MYSQL_HOST'),
            user=os.environ.get('MYSQL_USERNAME'),
            password=os.environ.get('MYSQL_PASSWORD'),
            database=os.environ.get('MYSQL_DATABASE'),
            charset=os.environ.get('MYSQL_CHARSET', 'utf8'),
            cursorclass=pymysql.cursors.DictCursor
        )
    return g.db_conn


@app.teardown_appcontext
def close_db(exception=None):
    """请求结束时关闭数据库连接"""
    conn = g.pop('db_conn', None)
    if conn is not None:
        conn.close()


def query_sql(sql, args=None, fetch=True, commit=False):
    """执行SQL查询, 同一请求复用连接"""
    conn = get_db()
    with conn.cursor() as cur:
        cur.execute(sql, args or ())
        if commit:
            conn.commit()
        if fetch:
            return cur.fetchall()
        return cur.lastrowid


def insert_sql(sql, args=None):
    return query_sql(sql, args, fetch=False, commit=True)


def update_sql(sql, args=None):
    query_sql(sql, args, fetch=False, commit=True)


# ------------------------------------------------------------
# 登录认证装饰器
# ------------------------------------------------------------
def login_required(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        if not session.get('admin_id'):
            if request.path.startswith('/api/'):
                return jsonify({'code': 401, 'msg': '未登录'}), 401
            return redirect(url_for('admin_login', next=request.path))
        return f(*args, **kwargs)
    return wrapper


def super_required(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        if session.get('role') != 'super':
            flash('权限不足', 'danger')
            return redirect(url_for('admin_dashboard'))
        return f(*args, **kwargs)
    return wrapper


# ------------------------------------------------------------
# 工具函数
# ------------------------------------------------------------
def record_log(module, action, target_id=None):
    admin_id = session.get('admin_id')
    username = session.get('username')
    ip = request.remote_addr
    ua = request.user_agent.string[:500]
    try:
        insert_sql(
            "INSERT INTO logs (admin_id, username, module, action, target_id, ip, user_agent) "
            "VALUES (%s, %s, %s, %s, %s, %s)",
            (admin_id, username, module, action, target_id, ip, ua)
        )
    except Exception:
        pass


def get_pagination():
    page = int(request.args.get('page', 1))
    per_page = int(request.args.get('per_page', 20))
    if page < 1:
        page = 1
    return page, per_page


def paginate(count_sql, list_sql, page, per_page, args=None):
    total = query_sql(count_sql, args)[0]['cnt']
    offset = (page - 1) * per_page
    items = query_sql(list_sql + " LIMIT %s OFFSET %s", list(args) + [per_page, offset] if args else [per_page, offset])
    total_pages = (total + per_page - 1) // per_page
    return {
        'items': items,
        'total': total,
        'page': page,
        'per_page': per_page,
        'total_pages': total_pages,
        'has_prev': page > 1,
        'has_next': page < total_pages,
        'prev_num': page - 1,
        'next_num': page + 1,
    }


# ============================================================
# 官网前端路由
# ============================================================
def common_context():
    """所有前端页面共享的变量"""
    try:
        configs = query_sql("SELECT config_key, config_value FROM site_configs")
    except Exception:
        configs = []
    cfg = {c['config_key']: c['config_value'] for c in configs}
    return {
        'site_name': cfg.get('site_name', '安速通物流'),
        'site_title': cfg.get('site_title', '安速通物流'),
        'site_keywords': cfg.get('site_keywords', ''),
        'site_description': cfg.get('site_description', ''),
        'copyright': cfg.get('site_copyright', ''),
        'hotline': cfg.get('service_hotline', '400-888-8888'),
        'company_address': cfg.get('company_address', ''),
        'banners': query_sql("SELECT * FROM banners WHERE position='home' AND status=1 ORDER BY sort_order, id DESC"),
    }


@app.route('/')
def index():
    ctx = common_context()
    # 推荐业务 - 主营
    ctx['business_main'] = query_sql(
        "SELECT * FROM business_intros WHERE category='main' AND status=1 ORDER BY sort_order, id DESC LIMIT 6")
    ctx['business_value'] = query_sql(
        "SELECT * FROM business_intros WHERE category='value_added' AND status=1 ORDER BY sort_order, id DESC LIMIT 4")
    # 推荐新闻
    ctx['news_latest'] = query_sql(
        "SELECT * FROM news WHERE status=1 ORDER BY sort_order, id DESC LIMIT 6")
    # 网点(按省份分组取前几个)
    ctx['branches_latest'] = query_sql(
        "SELECT * FROM branches WHERE status=1 ORDER BY sort_order, id DESC LIMIT 8")
    return render_template('front/index.html', **ctx)


@app.route('/business/<category>')
def business_list(category):
    ctx = common_context()
    if category not in ('main', 'value_added', 'marketing'):
        abort(404)
    titles = {'main': '主营产品', 'value_added': '增值服务', 'marketing': '市场活动'}
    ctx['title'] = titles[category]
    ctx['category'] = category
    ctx['items'] = query_sql(
        "SELECT * FROM business_intros WHERE category=%s AND status=1 ORDER BY sort_order, id DESC", (category,))
    return render_template('front/business_list.html', **ctx)


@app.route('/business/detail/<int:bid>')
def business_detail(bid):
    ctx = common_context()
    item = query_sql("SELECT * FROM business_intros WHERE id=%s", (bid,))
    if not item:
        abort(404)
    category = item[0].get('category', '')
    titles = {'main': '主营产品', 'value_added': '增值服务', 'marketing': '市场活动'}
    ctx['title'] = titles.get(category, '业务介绍')
    ctx['item'] = item[0]
    return render_template('front/business_detail.html', **ctx)


@app.route('/hall/<category>')
def hall_list(category):
    ctx = common_context()
    if category not in ('price', 'wechat', 'forbidden'):
        abort(404)
    titles = {'price': '价格与时效', 'wechat': '微信服务', 'forbidden': '禁运品'}
    ctx['title'] = titles[category]
    ctx['category'] = category
    ctx['items'] = query_sql(
        "SELECT * FROM online_halls WHERE category=%s AND status=1 ORDER BY sort_order, id DESC", (category,))
    return render_template('front/hall_list.html', **ctx)


@app.route('/hall/detail/<int:hid>')
def hall_detail(hid):
    ctx = common_context()
    item = query_sql("SELECT * FROM online_halls WHERE id=%s", (hid,))
    if not item:
        abort(404)
    category = item[0].get('category', '')
    titles = {'price': '价格与时效', 'wechat': '微信服务', 'forbidden': '禁运品'}
    ctx['title'] = titles.get(category, '网上营业厅')
    ctx['category'] = category
    ctx['item'] = item[0]
    ctx['back_url'] = '/hall/' + category
    ctx['back_name'] = '返回列表'
    return render_template('front/news_detail.html', **ctx)


@app.route('/tracking', methods=['GET', 'POST'])
def tracking():
    ctx = common_context()
    ctx['tracking_no'] = request.values.get('tracking_no', '').strip()
    ctx['result'] = None
    if request.method == 'POST' and ctx['tracking_no']:
        main = query_sql("SELECT * FROM trackings WHERE tracking_no=%s", (ctx['tracking_no'],))
        if main:
            details = query_sql(
                "SELECT * FROM tracking_details WHERE tracking_id=%s ORDER BY node_time DESC, sort_order",
                (main[0]['id'],))
            ctx['result'] = {'main': main[0], 'details': details}
        else:
            ctx['not_found'] = True
    return render_template('front/tracking.html', **ctx)


@app.route('/help/<category>')
def help_list(category):
    ctx = common_context()
    if category not in ('knowledge', 'download'):
        abort(404)
    titles = {'knowledge': '基本常识', 'download': '下载中心'}
    ctx['title'] = titles[category]
    ctx['category'] = category
    ctx['items'] = query_sql(
        "SELECT * FROM helps WHERE category=%s AND status=1 ORDER BY sort_order, id DESC", (category,))
    return render_template('front/help_list.html', **ctx)


@app.route('/help/detail/<int:hid>')
def help_detail(hid):
    ctx = common_context()
    item = query_sql("SELECT * FROM helps WHERE id=%s", (hid,))
    if not item:
        abort(404)
    ctx['item'] = item[0]
    return render_template('front/help_detail.html', **ctx)


@app.route('/news/<category>')
def news_list(category):
    ctx = common_context()
    if category not in ('company', 'industry'):
        abort(404)
    titles = {'company': '新闻中心', 'industry': '行业资讯'}
    ctx['title'] = titles[category]
    ctx['category'] = category
    ctx['items'] = query_sql(
        "SELECT * FROM news WHERE category=%s AND status=1 ORDER BY sort_order, id DESC",
        (category,))
    return render_template('front/news_list.html', **ctx)


@app.route('/news/detail/<int:nid>')
def news_detail(nid):
    ctx = common_context()
    item = query_sql("SELECT * FROM news WHERE id=%s", (nid,))
    if not item:
        abort(404)
    ctx['item'] = item[0]
    return render_template('front/news_detail.html', **ctx)


@app.route('/branches')
def branches_list():
    ctx = common_context()
    items = query_sql("SELECT * FROM branches WHERE status=1 ORDER BY sort_order, id DESC")
    # 按省份分组
    groups = {}
    for it in items:
        p = it.get('province') or '其他'
        groups.setdefault(p, []).append(it)
    ctx['province_groups'] = groups
    ctx['items'] = items
    return render_template('front/branches.html', **ctx)


@app.route('/about/<category>')
def about_page(category):
    ctx = common_context()
    if category not in ('profile', 'history', 'recruit', 'video', 'notice', 'structure', 'culture'):
        abort(404)
    titles = {'profile': '公司简介', 'history': '发展历程', 'recruit': '人才招聘',
              'video': '走进安速通', 'notice': '公司公告', 'structure': '组织架构', 'culture': '企业文化'}
    ctx['title'] = titles[category]
    ctx['category'] = category
    ctx['items'] = query_sql(
        "SELECT * FROM abouts WHERE category=%s AND status=1 ORDER BY sort_order, id DESC",
        (category,))
    return render_template('front/about.html', **ctx)


@app.route('/about/detail/<int:aid>')
def about_detail(aid):
    ctx = common_context()
    item = query_sql("SELECT * FROM abouts WHERE id=%s", (aid,))
    if not item:
        abort(404)
    ctx['item'] = item[0]
    return render_template('front/about_detail.html', **ctx)


@app.route('/contact', methods=['GET', 'POST'])
def contact_page():
    ctx = common_context()
    ctx['company'] = query_sql("SELECT * FROM contacts WHERE type='company' AND status=1 ORDER BY sort_order, id DESC LIMIT 1")
    ctx['company'] = ctx['company'][0] if ctx['company'] else {}
    if request.method == 'POST':
        data = request.form
        try:
            insert_sql(
                "INSERT INTO contacts (type, name, company, phone, email, subject, message) "
                "VALUES ('inquiry', %s, %s, %s, %s, %s, %s)",
                (data.get('name'), data.get('company'), data.get('phone'),
                 data.get('email'), data.get('subject'), data.get('message'))
            )
            ctx['success'] = True
        except Exception as e:
            ctx['error'] = str(e)
    return render_template('front/contact.html', **ctx)


# ============================================================
# 后台管理 - 登录
# ============================================================
def _ensure_default_admin():
    """初始化时确保有 admin / admin123 账号"""
    try:
        existing = query_sql("SELECT * FROM admins WHERE username=%s LIMIT 1", ('admin',))
        if existing:
            # 已存在admin账号,但检查密码是否仍有效(防止早期遗留的无效hash)
            stored_pw = existing[0]['password']
            pw_ok = False
            try:
                pw_ok = check_password_hash(stored_pw, 'admin123')
            except Exception:
                pw_ok = False
            if not pw_ok and stored_pw != 'admin123':
                hashed = generate_password_hash('admin123')
                update_sql("UPDATE admins SET password=%s WHERE username=%s", (hashed, 'admin'))
            return
        hashed = generate_password_hash('admin123')
        insert_sql("INSERT INTO admins (username, password, real_name, role, status) VALUES (%s, %s, %s, %s, %s)",
                   ('admin', hashed, '超级管理员', 'super', 1))
    except Exception:
        pass


@app.route('/admin/login', methods=['GET', 'POST'])
def admin_login():
    _ensure_default_admin()
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        password = request.form.get('password', '')
        try:
            admins = query_sql("SELECT * FROM admins WHERE username=%s LIMIT 1", (username,))
        except Exception:
            flash('数据库访问异常,请确认数据表已创建', 'danger')
            return render_template('admin/login.html')
        if not admins:
            flash('账号或密码错误', 'danger')
            return render_template('admin/login.html')
        admin = admins[0]
        if admin['status'] != 1:
            flash('账号已被禁用', 'danger')
            return render_template('admin/login.html')
        ok = False
        try:
            ok = check_password_hash(admin['password'], password)
        except Exception:
            ok = False
        # 兜底:支持明文(仅首次初始化时,正式环境请移除)
        if not ok and admin['password'] == password:
            ok = True
        if not ok:
            flash('账号或密码错误', 'danger')
            return render_template('admin/login.html')
        session['admin_id'] = admin['id']
        session['username'] = admin['username']
        session['real_name'] = admin['real_name'] or admin['username']
        session['role'] = admin['role']
        session.permanent = True
        try:
            update_sql("UPDATE admins SET last_login=NOW() WHERE id=%s", (admin['id'],))
        except Exception:
            pass
        record_log('auth', '登录成功', admin['id'])
        return redirect(request.args.get('next') or url_for('admin_dashboard'))
    if session.get('admin_id'):
        return redirect(url_for('admin_dashboard'))
    return render_template('admin/login.html')


@app.route('/admin/logout')
def admin_logout():
    record_log('auth', '登出')
    session.clear()
    return redirect(url_for('admin_login'))


# ============================================================
# 后台管理 - 仪表盘
# ============================================================
@app.route('/admin')
@app.route('/admin/dashboard')
@login_required
def admin_dashboard():
    stats = {}
    for table, label in [('news', '新闻'), ('branches', '网点'), ('trackings', '运单'),
                         ('business_intros', '业务'), ('helps', '帮助'), ('abouts', '关于')]:
        try:
            r = query_sql(f"SELECT COUNT(*) AS cnt FROM {table}")
            stats[label] = r[0]['cnt']
        except Exception:
            stats[label] = 0
    try:
        inquiries = query_sql(
            "SELECT * FROM contacts WHERE type='inquiry' ORDER BY id DESC LIMIT 10")
    except Exception:
        inquiries = []
    return render_template('admin/dashboard.html', stats=stats, inquiries=inquiries)


# ------------------------------------------------------------
# 通用列表/编辑/删除辅助函数(避免重复代码)
# ------------------------------------------------------------
MODULE_CONFIG = {
    # 模块key: (表名, 显示名, 模板前缀, 分类选项)
    'business': ('business_intros', '业务介绍', 'generic',
                 [('main', '主营产品'), ('value_added', '增值服务'), ('marketing', '市场活动')]),
    'hall': ('online_halls', '网上营业厅', 'generic',
             [('price', '价格与时效'), ('wechat', '微信服务'), ('forbidden', '禁运品')]),
    'help': ('helps', '帮助与支持', 'generic',
             [('knowledge', '基本常识'), ('download', '下载中心')]),
    'news': ('news', '公司新闻', 'generic',
             [('company', '新闻中心'), ('industry', '行业资讯')]),
    'abouts': ('abouts', '关于安速通', 'generic',
             [('profile', '公司简介'), ('history', '发展历程'), ('recruit', '人才招聘'),
              ('video', '走进安速通'), ('notice', '公司公告'), ('structure', '组织架构'),
              ('culture', '企业文化')]),
}


def admin_generic_list(module_key):
    table, mod_name, tpl_prefix, cats = MODULE_CONFIG[module_key]
    page, per_page = get_pagination()
    category = request.args.get('category', '')
    keyword = request.args.get('keyword', '').strip()
    where = "WHERE 1=1"
    args = []
    if category:
        where += " AND category=%s"
        args.append(category)
    if keyword:
        where += " AND (title LIKE %s OR content LIKE %s)"
        kw = f"%{keyword}%"
        args.extend([kw, kw])
    count_sql = f"SELECT COUNT(*) AS cnt FROM {table} {where}"
    list_sql = f"SELECT * FROM {table} {where} ORDER BY sort_order, id DESC"
    data = paginate(count_sql, list_sql, page, per_page, args or None)
    return render_template(f'admin/{tpl_prefix}_list.html',
                           items=data['items'], page=data['page'], total=data['total'],
                           total_pages=data['total_pages'],
                           categories=cats, current_category=category, keyword=keyword,
                           module_key=module_key, module_name=mod_name,
                           has_prev=data['has_prev'], has_next=data['has_next'],
                           prev_num=data['prev_num'], next_num=data['next_num'])


def admin_generic_form(module_key, item_id=None):
    table, mod_name, tpl_prefix, cats = MODULE_CONFIG[module_key]
    item = {}
    if item_id:
        r = query_sql(f"SELECT * FROM {table} WHERE id=%s", (item_id,))
        if r:
            item = r[0]
    if request.method == 'POST':
        data = request.form.to_dict()
        fields = ['category', 'title', 'content', 'sort_order', 'status']
        col_names = [c['Field'] for c in query_sql(f"DESCRIBE {table}")]
        valid_fields = [k for k in fields if k in col_names and k in data]
        values = []
        for k in valid_fields:
            v = data.get(k, '').strip()
            if v == '' and k in ('sort_order', 'status'):
                v = 0
            values.append(v)
        if item_id:
            set_clauses = [f"`{k}`=%s" for k in valid_fields]
            sql = f"UPDATE {table} SET " + ", ".join(set_clauses) + " WHERE id=%s"
            update_sql(sql, values + [item_id])
            record_log(mod_name, '修改', item_id)
        else:
            cols_ins = [f"`{k}`" for k in valid_fields]
            ph = ", ".join(["%s"] * len(cols_ins))
            sql = f"INSERT INTO {table} ({', '.join(cols_ins)}) VALUES ({ph})"
            new_id = insert_sql(sql, values)
            record_log(mod_name, '新增', new_id)
        flash('保存成功', 'success')
        return redirect(url_for('admin_module_list', module=module_key))
    return render_template(f'admin/{tpl_prefix}_form.html', item=item, categories=cats,
                           module_key=module_key, module_name=mod_name)


def admin_generic_delete(module_key, item_id):
    table, mod_name, _, _ = MODULE_CONFIG[module_key]
    update_sql(f"DELETE FROM {table} WHERE id=%s", (item_id,))
    record_log(mod_name, '删除', item_id)
    flash('删除成功', 'success')
    return redirect(request.referrer or url_for('admin_module_list', module=module_key))


# ============================================================
# 后台 - 通用 CRUD 路由（business / hall / help / news / abouts）
# ============================================================
_CRUD_MODULES = {'business', 'hall', 'help', 'news', 'abouts'}


@app.route('/admin/<module>/')
@login_required
def admin_module_list(module):
    """通用列表: /admin/business, /admin/news, /admin/help, /admin/hall, /admin/abouts"""
    if module not in _CRUD_MODULES:
        abort(404)
    return admin_generic_list(module)


@app.route('/admin/<module>/new', methods=['GET', 'POST'])
@login_required
def admin_module_new(module):
    if module not in _CRUD_MODULES:
        abort(404)
    return admin_generic_form(module)


@app.route('/admin/<module>/edit/<int:item_id>', methods=['GET', 'POST'])
@login_required
def admin_module_edit(module, item_id):
    if module not in _CRUD_MODULES:
        abort(404)
    return admin_generic_form(module, item_id)


@app.route('/admin/<module>/delete/<int:item_id>')
@login_required
def admin_module_delete(module, item_id):
    if module not in _CRUD_MODULES:
        abort(404)
    return admin_generic_delete(module, item_id)


# ============================================================
# 后台 - 货物追踪
# ============================================================
_TRACKING_FIELDS = [
    ('tracking_no', str),          # 快递单号
    ('shipping_time', str),        # 托运时间
    ('origin', str),               # 始发地
    ('destination', str),          # 目的地
    ('sender_company', str),       # 寄件公司
    ('sender', str),               # 发件人
    ('sender_phone', str),         # 发件人电话
    ('receiver_company', str),     # 收件公司
    ('receiver', str),             # 收件人
    ('receiver_phone', str),       # 收件人电话
    ('transport_type', str),       # 运输类型
    ('goods_name', str),           # 品名
    ('weight', float),             # 重量
    ('volume', float),             # 体积
    ('pieces', int),               # 件数
    ('package', str),              # 包装
    ('delivery_method', str),      # 送货方式
    ('need_receipt', str),         # 签回单
    ('receipt_remark', str),       # 回单备注
    ('receipt_status', str),       # 回单情况
    ('remark', str),               # 备注
    ('charge_weight', float),      # 计费重量
    ('package_fee', float),        # 包装费
    ('pickup_request', str),       # 提货要求
    ('unload_fee', float),         # 卸货费
    ('other_fee', float),          # 其它费用
    ('insurance', float),          # 保险
    ('freight', float),            # 运费
    ('cod_amount', float),         # 到付金额
    ('payment_method', str),       # 付款方式
    ('status', str),               # 目前状态
]


def _collect_tracking_values(form_data, for_insert=True):
    """按白名单收集表单字段,转换类型,空值→None/0"""
    values = []
    for name, ftype in _TRACKING_FIELDS:
        raw = form_data.get(name, '').strip()
        if raw == '':
            values.append(None if ftype is str else 0)
        else:
            try:
                values.append(ftype(raw))
            except Exception:
                values.append(raw)
    return values


@app.route('/admin/tracking')
@login_required
def admin_tracking():
    page, per_page = get_pagination()
    keyword = request.args.get('keyword', '').strip()
    status = request.args.get('status', '')
    where = "WHERE 1=1"
    args = []
    if keyword:
        where += " AND (tracking_no LIKE %s OR sender LIKE %s OR receiver LIKE %s OR sender_company LIKE %s)"
        kw = f"%{keyword}%"
        args.extend([kw, kw, kw, kw])
    if status:
        where += " AND status=%s"
        args.append(status)
    count_sql = f"SELECT COUNT(*) AS cnt FROM trackings {where}"
    list_sql = f"SELECT * FROM trackings {where} ORDER BY id DESC"
    data = paginate(count_sql, list_sql, page, per_page, args or None)
    return render_template('admin/tracking_list.html', items=data['items'],
                           page=data['page'], total=data['total'],
                           total_pages=data['total_pages'], keyword=keyword,
                           status=status, has_prev=data['has_prev'],
                           has_next=data['has_next'], prev_num=data['prev_num'],
                           next_num=data['next_num'])


@app.route('/admin/tracking/new', methods=['GET', 'POST'])
@login_required
def admin_tracking_new():
    if request.method == 'POST':
        d = request.form
        try:
            cols = ', '.join([f'`{n}`' for n, _ in _TRACKING_FIELDS])
            ph = ', '.join(['%s'] * len(_TRACKING_FIELDS))
            sql = f"INSERT INTO trackings ({cols}) VALUES ({ph})"
            vals = _collect_tracking_values(d, for_insert=True)
            new_id = insert_sql(sql, vals)
            record_log('tracking', '新增运单', new_id)
            flash('运单创建成功,请继续添加物流节点', 'success')
            return redirect(url_for('admin_tracking_detail', tid=new_id))
        except Exception as e:
            flash('保存失败: ' + str(e), 'danger')
    return render_template('admin/tracking_form.html', item={})


@app.route('/admin/tracking/edit/<int:tid>', methods=['GET', 'POST'])
@login_required
def admin_tracking_edit(tid):
    r = query_sql("SELECT * FROM trackings WHERE id=%s", (tid,))
    if not r:
        flash('记录不存在', 'danger')
        return redirect(url_for('admin_tracking'))
    if request.method == 'POST':
        d = request.form
        set_clauses = ', '.join([f'`{n}`=%s' for n, _ in _TRACKING_FIELDS])
        sql = f"UPDATE trackings SET {set_clauses} WHERE id=%s"
        vals = _collect_tracking_values(d, for_insert=False) + [tid]
        update_sql(sql, vals)
        record_log('tracking', '修改运单', tid)
        flash('保存成功', 'success')
        return redirect(url_for('admin_tracking'))
    return render_template('admin/tracking_form.html', item=r[0])


@app.route('/admin/tracking/detail/<int:tid>', methods=['GET', 'POST'])
@login_required
def admin_tracking_detail(tid):
    r = query_sql("SELECT * FROM trackings WHERE id=%s", (tid,))
    if not r:
        flash('记录不存在', 'danger')
        return redirect(url_for('admin_tracking'))
    main = r[0]
    if request.method == 'POST':
        d = request.form
        node_time = d.get('node_time') or datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        insert_sql(
            "INSERT INTO tracking_details (tracking_id, tracking_no, node_time, location, status_text, operator, sort_order) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s)",
            (tid, main['tracking_no'], node_time, d.get('location'), d.get('status_text'),
             d.get('operator'), d.get('sort_order') or 0)
        )
        record_log('tracking', '新增节点', tid)
        flash('节点已添加', 'success')
        return redirect(url_for('admin_tracking_detail', tid=tid))
    details = query_sql(
        "SELECT * FROM tracking_details WHERE tracking_id=%s ORDER BY node_time DESC, id DESC", (tid,))
    return render_template('admin/tracking_detail.html', item=main, details=details)


@app.route('/admin/tracking/delete/<int:tid>')
@login_required
def admin_tracking_delete(tid):
    update_sql("DELETE FROM trackings WHERE id=%s", (tid,))
    update_sql("DELETE FROM tracking_details WHERE tracking_id=%s", (tid,))
    record_log('tracking', '删除运单', tid)
    flash('删除成功', 'success')
    return redirect(url_for('admin_tracking'))


@app.route('/admin/tracking/detail/delete/<int:did>')
@login_required
def admin_tracking_detail_delete(did):
    r = query_sql("SELECT tracking_id FROM tracking_details WHERE id=%s", (did,))
    update_sql("DELETE FROM tracking_details WHERE id=%s", (did,))
    record_log('tracking', '删除节点', did)
    flash('删除成功', 'success')
    if r:
        return redirect(url_for('admin_tracking_detail', tid=r[0]['tracking_id']))
    return redirect(url_for('admin_tracking'))


@app.route('/admin/tracking/print/<int:tid>')
@login_required
def admin_tracking_print(tid):
    """运单面单打印 - 独立的运单打印页面 """
    item = query_sql("SELECT * FROM trackings WHERE id=%s", (tid,))
    if not item:
        flash('运单不存在', 'error')
        return redirect(url_for('admin_tracking'))
    details = query_sql("SELECT * FROM tracking_details WHERE tracking_id=%s ORDER BY id DESC", (tid,))

    # 获取当前时间用于打印页
    from datetime import datetime
    now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

    return render_template('admin/tracking_print.html', item=item[0], details=details, now=now)


# ============================================================
# 后台 - 网点分布
# ============================================================
@app.route('/admin/branches')
@login_required
def admin_branches():
    page, per_page = get_pagination()
    keyword = request.args.get('keyword', '').strip()
    province = request.args.get('province', '')
    where = "WHERE 1=1"
    args = []
    if keyword:
        where += " AND (branch_name LIKE %s OR address LIKE %s OR manager LIKE %s OR phone LIKE %s)"
        kw = f"%{keyword}%"
        args.extend([kw, kw, kw, kw])
    if province:
        where += " AND province=%s"
        args.append(province)
    count_sql = f"SELECT COUNT(*) AS cnt FROM branches {where}"
    list_sql = f"SELECT * FROM branches {where} ORDER BY sort_order, id DESC"
    data = paginate(count_sql, list_sql, page, per_page, args or None)
    provinces = query_sql("SELECT DISTINCT province FROM branches WHERE province IS NOT NULL ORDER BY province")
    return render_template('admin/branches_list.html', items=data['items'],
                           page=data['page'], total=data['total'],
                           total_pages=data['total_pages'], keyword=keyword,
                           current_province=province,
                           provinces=[p['province'] for p in provinces if p['province']],
                           has_prev=data['has_prev'], has_next=data['has_next'],
                           prev_num=data['prev_num'], next_num=data['next_num'])


@app.route('/admin/branches/new', methods=['GET', 'POST'])
@login_required
def admin_branches_new():
    if request.method == 'POST':
        d = request.form
        insert_sql(
            "INSERT INTO branches (branch_name, province, city, district, address, phone, mobile, "
            "manager, business_scope, work_time, longitude, latitude, cover_image, description, "
            "sort_order, status) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)",
            (d.get('branch_name'), d.get('province'), d.get('city'), d.get('district'), d.get('address'),
             d.get('phone'), d.get('mobile'), d.get('manager'), d.get('business_scope'),
             d.get('work_time'), d.get('longitude') or None, d.get('latitude') or None,
             d.get('cover_image'), d.get('description'), d.get('sort_order') or 0, d.get('status', 1))
        )
        flash('保存成功', 'success')
        return redirect(url_for('admin_branches'))
    return render_template('admin/branches_form.html', item={})


@app.route('/admin/branches/edit/<int:item_id>', methods=['GET', 'POST'])
@login_required
def admin_branches_edit(item_id):
    r = query_sql("SELECT * FROM branches WHERE id=%s", (item_id,))
    if not r:
        flash('记录不存在', 'danger')
        return redirect(url_for('admin_branches'))
    if request.method == 'POST':
        d = request.form
        update_sql(
            "UPDATE branches SET branch_name=%s, province=%s, city=%s, district=%s, address=%s, "
            "phone=%s, mobile=%s, manager=%s, business_scope=%s, work_time=%s, longitude=%s, "
            "latitude=%s, cover_image=%s, description=%s, sort_order=%s, status=%s WHERE id=%s",
            (d.get('branch_name'), d.get('province'), d.get('city'), d.get('district'), d.get('address'),
             d.get('phone'), d.get('mobile'), d.get('manager'), d.get('business_scope'),
             d.get('work_time'), d.get('longitude') or None, d.get('latitude') or None,
             d.get('cover_image'), d.get('description'), d.get('sort_order') or 0, d.get('status', 1),
             item_id)
        )
        record_log('branches', '修改', item_id)
        flash('保存成功', 'success')
        return redirect(url_for('admin_branches'))
    return render_template('admin/branches_form.html', item=r[0])


@app.route('/admin/branches/delete/<int:item_id>')
@login_required
def admin_branches_delete(item_id):
    update_sql("DELETE FROM branches WHERE id=%s", (item_id,))
    record_log('branches', '删除', item_id)
    flash('删除成功', 'success')
    return redirect(url_for('admin_branches'))


# ============================================================
# 后台 - 关于安速通
# （使用动态路由 admin_module_list/form/delete）
# ============================================================


# ============================================================
# 后台 - 联系我们
# ============================================================
@app.route('/admin/contacts')
@login_required
def admin_contacts():
    page, per_page = get_pagination()
    type_ = request.args.get('type', 'inquiry')
    keyword = request.args.get('keyword', '').strip()
    where = "WHERE type=%s"
    args = [type_]
    if keyword:
        where += " AND (name LIKE %s OR phone LIKE %s OR email LIKE %s OR subject LIKE %s)"
        kw = f"%{keyword}%"
        args.extend([kw, kw, kw, kw])
    count_sql = f"SELECT COUNT(*) AS cnt FROM contacts {where}"
    list_sql = f"SELECT * FROM contacts {where} ORDER BY is_read, id DESC"
    data = paginate(count_sql, list_sql, page, per_page, args)
    return render_template('admin/contacts_list.html', items=data['items'],
                           page=data['page'], total=data['total'],
                           total_pages=data['total_pages'], keyword=keyword,
                           type=type_, has_prev=data['has_prev'],
                           has_next=data['has_next'], prev_num=data['prev_num'],
                           next_num=data['next_num'])


@app.route('/admin/contacts/detail/<int:cid>')
@login_required
def admin_contacts_detail(cid):
    r = query_sql("SELECT * FROM contacts WHERE id=%s", (cid,))
    if not r:
        flash('记录不存在', 'danger')
        return redirect(url_for('admin_contacts'))
    update_sql("UPDATE contacts SET is_read=1 WHERE id=%s", (cid,))
    return render_template('admin/contacts_detail.html', item=r[0])


@app.route('/admin/contacts/reply/<int:cid>', methods=['POST'])
@login_required
def admin_contacts_reply(cid):
    note = request.form.get('reply_note', '')
    update_sql("UPDATE contacts SET is_replied=1, reply_note=%s WHERE id=%s", (note, cid))
    flash('已标记为已回复', 'success')
    return redirect(url_for('admin_contacts_detail', cid=cid))


@app.route('/admin/contacts/delete/<int:cid>')
@login_required
def admin_contacts_delete(cid):
    update_sql("DELETE FROM contacts WHERE id=%s", (cid,))
    flash('删除成功', 'success')
    return redirect(url_for('admin_contacts'))


@app.route('/admin/contacts/company', methods=['GET', 'POST'])
@login_required
def admin_contacts_company():
    r = query_sql("SELECT * FROM contacts WHERE type='company' ORDER BY id DESC LIMIT 1")
    item = r[0] if r else {}
    if request.method == 'POST':
        d = request.form
        if item:
            update_sql(
                "UPDATE contacts SET name=%s, company=%s, phone=%s, email=%s, address=%s, "
                "service_hotline=%s, business_phone=%s, fax=%s, qq=%s, wechat=%s, work_time=%s, "
                "longitude=%s, latitude=%s, sort_order=%s, status=%s WHERE id=%s",
                (d.get('name'), d.get('company'), d.get('phone'), d.get('email'), d.get('address'),
                 d.get('service_hotline'), d.get('business_phone'), d.get('fax'), d.get('qq'),
                 d.get('wechat'), d.get('work_time'), d.get('longitude') or None,
                 d.get('latitude') or None, d.get('sort_order') or 0, d.get('status', 1), item['id'])
            )
            flash('更新成功', 'success')
        else:
            insert_sql(
                "INSERT INTO contacts (type, name, company, phone, email, address, service_hotline, "
                "business_phone, fax, qq, wechat, work_time, longitude, latitude, sort_order, status) "
                "VALUES ('company', %s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)",
                (d.get('name'), d.get('company'), d.get('phone'), d.get('email'), d.get('address'),
                 d.get('service_hotline'), d.get('business_phone'), d.get('fax'), d.get('qq'),
                 d.get('wechat'), d.get('work_time'), d.get('longitude') or None,
                 d.get('latitude') or None, d.get('sort_order') or 0, d.get('status', 1))
            )
            flash('保存成功', 'success')
        return redirect(url_for('admin_contacts_company'))
    return render_template('admin/contacts_company.html', item=item)


# ============================================================
# 后台 - Banner
# ============================================================
@app.route('/admin/banner')
@login_required
def admin_banner():
    page, per_page = get_pagination()
    count_sql = "SELECT COUNT(*) AS cnt FROM banners"
    list_sql = "SELECT * FROM banners ORDER BY sort_order, id DESC"
    data = paginate(count_sql, list_sql, page, per_page)
    return render_template('admin/banner_list.html', **data)


@app.route('/admin/banner/new', methods=['GET', 'POST'])
@login_required
def admin_banner_new():
    if request.method == 'POST':
        d = request.form
        insert_sql(
            "INSERT INTO banners (title, subtitle, image_url, link_url, position, sort_order, status) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s)",
            (d.get('title'), d.get('subtitle'), d.get('image_url'), d.get('link_url'),
             d.get('position', 'home'), d.get('sort_order') or 0, d.get('status', 1))
        )
        flash('保存成功', 'success')
        return redirect(url_for('admin_banner'))
    return render_template('admin/banner_form.html', item={})


@app.route('/admin/banner/edit/<int:item_id>', methods=['GET', 'POST'])
@login_required
def admin_banner_edit(item_id):
    r = query_sql("SELECT * FROM banners WHERE id=%s", (item_id,))
    if not r:
        flash('记录不存在', 'danger')
        return redirect(url_for('admin_banner'))
    if request.method == 'POST':
        d = request.form
        update_sql(
            "UPDATE banners SET title=%s, subtitle=%s, image_url=%s, link_url=%s, position=%s, "
            "sort_order=%s, status=%s WHERE id=%s",
            (d.get('title'), d.get('subtitle'), d.get('image_url'), d.get('link_url'),
             d.get('position', 'home'), d.get('sort_order') or 0, d.get('status', 1), item_id)
        )
        flash('保存成功', 'success')
        return redirect(url_for('admin_banner'))
    return render_template('admin/banner_form.html', item=r[0])


@app.route('/admin/banner/delete/<int:item_id>')
@login_required
def admin_banner_delete(item_id):
    update_sql("DELETE FROM banners WHERE id=%s", (item_id,))
    flash('删除成功', 'success')
    return redirect(url_for('admin_banner'))


# ============================================================
# 后台 - 站点配置
# ============================================================
@app.route('/admin/config', methods=['GET', 'POST'])
@login_required
def admin_config():
    if request.method == 'POST':
        d = request.form
        for key in ['site_name', 'site_title', 'site_keywords', 'site_description',
                    'site_copyright', 'service_hotline', 'company_address']:
            r = query_sql("SELECT id FROM site_configs WHERE config_key=%s", (key,))
            val = d.get(key, '')
            if r:
                update_sql("UPDATE site_configs SET config_value=%s WHERE config_key=%s", (val, key))
            else:
                insert_sql("INSERT INTO site_configs (config_key, config_value) VALUES (%s, %s)", (key, val))
        record_log('config', '修改站点配置')
        flash('保存成功', 'success')
        return redirect(url_for('admin_config'))
    configs = query_sql("SELECT config_key, config_value FROM site_configs")
    cfg = {c['config_key']: c['config_value'] for c in configs}
    return render_template('admin/config.html', cfg=cfg)


# ============================================================
# 后台 - 管理员管理(仅超级管理员)
# ============================================================
@app.route('/admin/admins')
@super_required
@login_required
def admin_admins():
    items = query_sql("SELECT * FROM admins ORDER BY id")
    return render_template('admin/admins_list.html', items=items)


@app.route('/admin/admins/new', methods=['GET', 'POST'])
@super_required
@login_required
def admin_admins_new():
    if request.method == 'POST':
        d = request.form
        username = d.get('username', '').strip()
        password = d.get('password', '')
        if not username or not password:
            flash('账号密码不能为空', 'danger')
            return render_template('admin/admins_form.html', item={})
        exists = query_sql("SELECT id FROM admins WHERE username=%s", (username,))
        if exists:
            flash('账号已存在', 'danger')
            return render_template('admin/admins_form.html', item={})
        hashed = generate_password_hash(password)
        insert_sql(
            "INSERT INTO admins (username, password, real_name, role, status) VALUES (%s,%s,%s,%s,%s)",
            (username, hashed, d.get('real_name'), d.get('role', 'editor'), d.get('status', 1))
        )
        flash('创建成功', 'success')
        return redirect(url_for('admin_admins'))
    return render_template('admin/admins_form.html', item={})


@app.route('/admin/admins/edit/<int:item_id>', methods=['GET', 'POST'])
@super_required
@login_required
def admin_admins_edit(item_id):
    r = query_sql("SELECT * FROM admins WHERE id=%s", (item_id,))
    if not r:
        flash('记录不存在', 'danger')
        return redirect(url_for('admin_admins'))
    if request.method == 'POST':
        d = request.form
        password = d.get('password', '')
        if password:
            hashed = generate_password_hash(password)
            update_sql(
                "UPDATE admins SET password=%s, real_name=%s, role=%s, status=%s WHERE id=%s",
                (hashed, d.get('real_name'), d.get('role', 'editor'), d.get('status', 1), item_id)
            )
        else:
            update_sql(
                "UPDATE admins SET real_name=%s, role=%s, status=%s WHERE id=%s",
                (d.get('real_name'), d.get('role', 'editor'), d.get('status', 1), item_id)
            )
        flash('更新成功', 'success')
        return redirect(url_for('admin_admins'))
    return render_template('admin/admins_form.html', item=r[0])


@app.route('/admin/admins/delete/<int:item_id>')
@super_required
@login_required
def admin_admins_delete(item_id):
    if item_id == session.get('admin_id'):
        flash('不能删除当前登录账号', 'danger')
        return redirect(url_for('admin_admins'))
    update_sql("DELETE FROM admins WHERE id=%s", (item_id,))
    flash('删除成功', 'success')
    return redirect(url_for('admin_admins'))


@app.route('/admin/admins/password', methods=['GET', 'POST'])
@login_required
def admin_admins_password():
    if request.method == 'POST':
        old = request.form.get('old_password', '')
        new = request.form.get('new_password', '')
        confirm = request.form.get('confirm_password', '')
        if not old or not new or not confirm:
            flash('请填写完整', 'danger')
        elif new != confirm:
            flash('两次输入的新密码不一致', 'danger')
        elif len(new) < 6:
            flash('新密码至少6位', 'danger')
        else:
            r = query_sql("SELECT password FROM admins WHERE id=%s", (session['admin_id'],))
            if r and check_password_hash(r[0]['password'], old):
                update_sql("UPDATE admins SET password=%s WHERE id=%s",
                           (generate_password_hash(new), session['admin_id']))
                flash('密码已更新', 'success')
                return redirect(url_for('admin_dashboard'))
            else:
                flash('原密码错误', 'danger')
    return render_template('admin/password.html')


# ============================================================
# 后台 - 操作日志
# ============================================================
@app.route('/admin/logs')
@super_required
@login_required
def admin_logs():
    page, per_page = get_pagination()
    count_sql = "SELECT COUNT(*) AS cnt FROM logs"
    list_sql = "SELECT * FROM logs ORDER BY id DESC"
    data = paginate(count_sql, list_sql, page, per_page)
    return render_template('admin/logs.html', **data)


# ============================================================
# API - 货物追踪查询
# ============================================================
@app.route('/api/tracking', methods=['POST'])
def api_tracking():
    no = (request.json.get('tracking_no') if request.is_json else request.form.get('tracking_no', '')).strip()
    if not no:
        return jsonify({'code': 400, 'msg': '请输入运单号'})
    main = query_sql("SELECT * FROM trackings WHERE tracking_no=%s", (no,))
    if not main:
        return jsonify({'code': 404, 'msg': '未查询到该运单,请核对后重试'})
    details = query_sql(
        "SELECT * FROM tracking_details WHERE tracking_id=%s ORDER BY node_time DESC, sort_order",
        (main[0]['id'],))
    return jsonify({'code': 0, 'msg': 'ok', 'main': main[0], 'details': details})


# ============================================================
# 错误页
# ============================================================
@app.errorhandler(404)
def page_not_found(e):
    return render_template('front/404.html', **common_context()), 404


@app.errorhandler(500)
def server_error(e):
    return str(e), 500


# ============================================================
# 启动入口
# ============================================================
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
